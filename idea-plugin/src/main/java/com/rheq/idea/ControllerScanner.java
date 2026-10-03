package com.rheq.idea;

import com.intellij.openapi.module.Module;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.project.Project;
import com.intellij.psi.*;
import com.intellij.psi.search.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;

final class ControllerScanner {
    enum Scope { METHOD, CONTROLLER, MODULE }
    record Export(Map<String, Object> document, List<String> warnings, int count) {}

    static Export scan(Project project, Module module, PsiClass selectedClass, PsiMethod selectedMethod, Scope scope, String baseUrl) {
        List<String> warnings = new ArrayList<>();
        String source = hash(project.getBasePath() + ":" + module.getName());
        Map<String, Map<String, Object>> paths = new TreeMap<>();
        ControllerOperation builder = new ControllerOperation(warnings);
        List<PsiClass> controllers = new ArrayList<>();
        if (scope == Scope.MODULE) {
            var files = FilenameIndex.getAllFilesByExt(project, "java", GlobalSearchScope.moduleScope(module));
            if (files.size() > 20000) throw new IllegalArgumentException("Module exceeds the 20000 Java file limit");
            for (var file : files) {
                ProgressManager.checkCanceled();
                PsiFile psi = PsiManager.getInstance(project).findFile(file);
                if (psi instanceof PsiJavaFile javaFile) for (PsiClass type : javaFile.getClasses()) collect(type, controllers);
            }
        } else if (selectedClass != null && SpringAnnotations.controller(selectedClass)) controllers.add(selectedClass);
        int count = 0;
        for (PsiClass controller : controllers) {
            String owner = controller.getQualifiedName();
            if (owner == null) continue;
            SpringAnnotations.Mapping classMapping = SpringAnnotations.mapping(controller);
            if (SpringAnnotations.composedMapping(controller)) { warnings.add(owner + ": custom mapping alias requires manual configuration"); continue; }
            List<String> classPaths;
            try { classPaths = classMapping == null ? List.of("") : SpringAnnotations.paths(classMapping.annotation()); }
            catch (IllegalArgumentException error) { warnings.add(owner + ": " + error.getMessage()); continue; }
            PsiMethod[] methods = scope == Scope.METHOD && selectedMethod != null ? new PsiMethod[] { selectedMethod } : controller.getAllMethods();
            for (PsiMethod method : methods) {
                ProgressManager.checkCanceled();
                SpringAnnotations.Mapping mapping = SpringAnnotations.mapping(method);
                if (mapping == null) for (PsiMethod parent : method.findSuperMethods()) {
                    mapping = SpringAnnotations.mapping(parent); if (mapping != null) break;
                }
                if (mapping == null) {
                    if (SpringAnnotations.composedMapping(method)) warnings.add(owner + "." + method.getName() + ": custom mapping alias requires manual configuration");
                    continue;
                }
                try {
                    List<String> verbs = mapping.verb().isEmpty() ? SpringAnnotations.strings(mapping.annotation(), "method") : List.of(mapping.verb());
                    List<String> classVerbs = classMapping == null ? List.of() : SpringAnnotations.strings(classMapping.annotation(), "method");
                    if (verbs.isEmpty()) verbs = classVerbs.isEmpty() ? List.of("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS") : classVerbs;
                    else if (!classVerbs.isEmpty()) verbs = verbs.stream().filter(classVerbs::contains).toList();
                    if (verbs.isEmpty()) { warnings.add(owner + "." + method.getName() + ": conflicting class/method HTTP conditions"); continue; }
                    if (method.findSuperMethods().length > 0) warnings.add(owner + "." + method.getName() + ": inherited parameter annotations require manual review");
                    int pathIndex = 0;
                    for (String prefix : classPaths) for (String path : SpringAnnotations.paths(mapping.annotation())) {
                        String full = join(prefix, path);
                        for (String verb : verbs) {
                            if (!Set.of("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS").contains(verb)) {
                                warnings.add(owner + "." + method.getName() + ": unsupported HTTP method " + verb); continue;
                            }
                            if (++count > 2000) throw new IllegalStateException("Export exceeds the 2000 operation limit");
                            String key = "rheq-code:" + source + ":" + owner + "#" + signature(method) + ":" + verb + ":" + pathIndex;
                            Map<String, Object> operation = builder.operation(method, controller.getName(), key);
                            List<String> consumes = SpringAnnotations.strings(mapping.annotation(), "consumes");
                            if (consumes.isEmpty() && classMapping != null) consumes = SpringAnnotations.strings(classMapping.annotation(), "consumes");
                            if (operation.containsKey("requestBody") && consumes.stream().anyMatch(c -> !c.equals("application/json")))
                                warnings.add(owner + "." + method.getName() + ": non-JSON consumes condition requires manual body configuration");
                            Map<String, Object> existing = paths.computeIfAbsent(full, ignored -> new LinkedHashMap<>());
                            if (existing.putIfAbsent(verb.toLowerCase(Locale.ROOT), operation) != null)
                                throw new IllegalArgumentException("Duplicate route " + verb + " " + full + "; inspect mapping conditions manually");
                            if (hasConditions(mapping) || hasConditions(classMapping))
                                warnings.add(owner + "." + method.getName() + ": mapping conditions require manual review");
                        }
                        pathIndex++;
                    }
                } catch (IllegalArgumentException error) { warnings.add(owner + "." + method.getName() + ": " + error.getMessage()); }
            }
        }
        count = paths.values().stream().mapToInt(Map::size).sum();
        String scopeKey = scope == Scope.MODULE ? "module" : selectedClass.getQualifiedName() + (scope == Scope.METHOD ? "#" + signature(selectedMethod) : "");
        Map<String, Object> bridge = Map.of("version", 1, "sourceId", source, "scope", scope.name().toLowerCase(Locale.ROOT), "scopeKey", scopeKey,
            "baseUrl", baseUrl, "warnings", List.copyOf(warnings));
        return new Export(Map.of("openapi", "3.0.3", "info", Map.of("title", module.getName(), "version", "1"),
            "servers", List.of(Map.of("url", baseUrl)), "paths", paths, "x-rheq-bridge", bridge), warnings, count);
    }

    private static boolean hasConditions(SpringAnnotations.Mapping mapping) {
        return mapping != null && (!SpringAnnotations.strings(mapping.annotation(), "params").isEmpty()
            || !SpringAnnotations.strings(mapping.annotation(), "headers").isEmpty());
    }

    private static void collect(PsiClass type, List<PsiClass> result) {
        if (SpringAnnotations.controller(type)) result.add(type);
        for (PsiClass inner : type.getInnerClasses()) collect(inner, result);
    }
    private static String signature(PsiMethod method) {
        return method.getName() + "(" + String.join(",", Arrays.stream(method.getParameterList().getParameters()).map(p -> p.getType().getCanonicalText()).toList()) + ")";
    }
    static String join(String prefix, String path) {
        String result = ("/" + prefix + "/" + path).replaceAll("/+", "/");
        if (result.length() > 1 && result.endsWith("/")) result = result.substring(0, result.length() - 1);
        return result;
    }
    private static String hash(String text) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8))).substring(0, 24); }
        catch (java.security.NoSuchAlgorithmException error) { throw new IllegalStateException(error); }
    }
}
