package com.rheq.idea;

import com.intellij.psi.*;
import java.util.*;

final class SpringAnnotations {
    private static final String WEB = "org.springframework.web.bind.annotation.";
    record Mapping(PsiAnnotation annotation, String verb) {}

    static boolean controller(PsiClass type) {
        return find(type, Set.of(WEB + "RestController", "org.springframework.stereotype.Controller"), new HashSet<>()) != null;
    }

    static Mapping mapping(PsiModifierListOwner owner) {
        Map<String, String> names = Map.of("RequestMapping", "", "GetMapping", "GET", "PostMapping", "POST",
            "PutMapping", "PUT", "DeleteMapping", "DELETE", "PatchMapping", "PATCH");
        PsiModifierList list = owner.getModifierList();
        if (list == null) return null;
        for (PsiAnnotation annotation : list.getAnnotations()) {
            String qualified = annotation.getQualifiedName();
            if (qualified != null && qualified.startsWith(WEB)) {
                String simple = qualified.substring(WEB.length());
                if (names.containsKey(simple)) return new Mapping(annotation, names.get(simple));
            }
        }
        return null;
    }

    static boolean composedMapping(PsiModifierListOwner owner) {
        return mapping(owner) == null && find(owner, Set.of(WEB + "RequestMapping", WEB + "GetMapping", WEB + "PostMapping",
            WEB + "PutMapping", WEB + "DeleteMapping", WEB + "PatchMapping"), new HashSet<>()) != null;
    }

    static PsiAnnotation direct(PsiModifierListOwner owner, String shortName) {
        return find(owner, Set.of(WEB + shortName), new HashSet<>());
    }

    private static PsiAnnotation find(PsiModifierListOwner owner, Set<String> names, Set<String> visited) {
        PsiModifierList list = owner.getModifierList();
        if (list == null || visited.size() > 16) return null;
        for (PsiAnnotation annotation : list.getAnnotations()) {
            String name = annotation.getQualifiedName();
            if (name == null) continue;
            if (names.contains(name)) return annotation;
            if (!name.startsWith("java.") && visited.add(name)) {
                PsiClass type = annotation.resolveAnnotationType();
                if (type != null) {
                    PsiAnnotation nested = find(type, names, visited);
                    if (nested != null) return nested;
                }
            }
        }
        return null;
    }

    static List<String> strings(PsiAnnotation annotation, String attribute) {
        if (annotation == null) return List.of();
        PsiAnnotationMemberValue value = annotation.findAttributeValue(attribute);
        if (value == null) return List.of();
        List<String> values = new ArrayList<>();
        if (value instanceof PsiArrayInitializerMemberValue array) {
            for (PsiAnnotationMemberValue item : array.getInitializers()) values.add(constant(item));
        } else values.add(constant(value));
        return values.stream().filter(v -> !v.isEmpty()).toList();
    }

    static String constant(PsiAnnotationMemberValue value) {
        Object result = JavaPsiFacade.getInstance(value.getProject()).getConstantEvaluationHelper().computeConstantExpression(value);
        if (result instanceof String text) return text;
        if (result instanceof Number || result instanceof Boolean) return result.toString();
        if (value instanceof PsiReferenceExpression ref && ref.resolve() instanceof PsiEnumConstant e) return e.getName();
        throw new IllegalArgumentException("Unresolved annotation value: " + value.getText());
    }

    static String string(PsiAnnotation annotation, String attribute, String fallback) {
        List<String> values = strings(annotation, attribute);
        return values.isEmpty() ? fallback : values.getFirst();
    }

    static List<String> paths(PsiAnnotation annotation) {
        List<String> paths = strings(annotation, "path");
        if (paths.isEmpty()) paths = strings(annotation, "value");
        if (paths.isEmpty()) return List.of("");
        if (paths.stream().anyMatch(p -> p.contains("${") || p.contains("#{") || p.contains("*") || p.matches(".*\\{[^}]*:[^}]*}.*")))
            throw new IllegalArgumentException("Dynamic, wildcard or regex path requires manual configuration");
        return paths.stream().sorted().toList();
    }

    static String summary(PsiMethod method) {
        PsiModifierList list = method.getModifierList();
        PsiAnnotation operation = list.findAnnotation("io.swagger.v3.oas.annotations.Operation");
        if (operation != null) return string(operation, "summary", method.getName());
        PsiAnnotation legacy = list.findAnnotation("io.swagger.annotations.ApiOperation");
        if (legacy != null) return string(legacy, "value", method.getName());
        return method.getName();
    }
}
