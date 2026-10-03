package com.rheq.idea;

import com.intellij.psi.*;
import java.util.*;

final class DtoSchema {
    private final List<String> warnings;
    DtoSchema(List<String> warnings) { this.warnings = warnings; }

    Map<String, Object> schema(PsiType type) { return schema(type, new HashSet<>(), 0); }
    private Map<String, Object> schema(PsiType type, Set<String> seen, int depth) {
        String name = type.getCanonicalText();
        if (type instanceof PsiArrayType array) return Map.of("type", "array", "items", schema(array.getComponentType(), seen, depth + 1));
        if (Set.of("boolean", "java.lang.Boolean").contains(name)) return Map.of("type", "boolean", "example", false);
        if (Set.of("byte", "short", "int", "long", "java.lang.Byte", "java.lang.Short", "java.lang.Integer", "java.lang.Long", "java.math.BigInteger").contains(name))
            return Map.of("type", "integer", "example", 1);
        if (Set.of("float", "double", "java.lang.Float", "java.lang.Double", "java.math.BigDecimal").contains(name))
            return Map.of("type", "number", "example", 1);
        if (name.equals("java.lang.String") || name.equals("char") || name.equals("java.lang.Character")) return Map.of("type", "string", "example", "example");
        if (name.contains("MultipartFile")) return Map.of("type", "string", "format", "binary");
        if (name.equals("java.util.UUID")) return Map.of("type", "string", "format", "uuid", "example", "00000000-0000-0000-0000-000000000001");
        if (name.startsWith("java.time.") || name.equals("java.util.Date")) return Map.of("type", "string");
        if (!(type instanceof PsiClassType classType)) return Map.of("type", "object");
        PsiClassType.ClassResolveResult resolved = classType.resolveGenerics();
        PsiClass clazz = resolved.getElement();
        if (clazz == null) { warnings.add("Unresolved DTO: " + name); return Map.of("type", "object"); }
        String qualified = Objects.toString(clazz.getQualifiedName(), "");
        PsiType[] parameters = classType.getParameters();
        if (Set.of("java.util.List", "java.util.Set", "java.util.Collection", "java.lang.Iterable").contains(qualified))
            return Map.of("type", "array", "items", parameters.length > 0 ? schema(parameters[0], seen, depth + 1) : Map.of("type", "object"));
        if ("java.util.Optional".equals(qualified) && parameters.length > 0) return schema(parameters[0], seen, depth + 1);
        if ("java.util.Map".equals(qualified)) return Map.of("type", "object", "additionalProperties",
            parameters.length > 1 ? schema(parameters[1], seen, depth + 1) : Map.of("type", "object"));
        if (clazz.isEnum()) return Map.of("type", "string", "enum", Arrays.stream(clazz.getFields())
            .filter(f -> f instanceof PsiEnumConstant).map(PsiField::getName).toList());
        if (depth >= 8 || !seen.add(name)) { warnings.add("Recursive or deep DTO truncated: " + name); return Map.of("type", "object"); }
        Map<String, Object> properties = new LinkedHashMap<>();
        List<String> required = new ArrayList<>();
        for (PsiField field : clazz.getAllFields()) {
            if (field.hasModifierProperty(PsiModifier.STATIC) || field.hasModifierProperty(PsiModifier.TRANSIENT)) continue;
            PsiModifierList modifiers = field.getModifierList();
            if (modifiers != null) {
                PsiAnnotation ignored = modifiers.findAnnotation("com.fasterxml.jackson.annotation.JsonIgnore");
                if (ignored != null && !SpringAnnotations.string(ignored, "value", "true").equals("false")) continue;
            }
            String key = field.getName();
            if (modifiers != null) {
                PsiAnnotation property = modifiers.findAnnotation("com.fasterxml.jackson.annotation.JsonProperty");
                if (property != null) key = SpringAnnotations.string(property, "value", key);
            }
            PsiType fieldType = resolved.getSubstitutor().substitute(field.getType());
            Map<String, Object> child = new LinkedHashMap<>(schema(fieldType == null ? field.getType() : fieldType, new HashSet<>(seen), depth + 1));
            if (modifiers != null) applyValidation(modifiers, key, child, required);
            properties.putIfAbsent(key, child);
            if (properties.size() >= 100) { warnings.add("DTO field limit reached: " + name); break; }
        }
        if (clazz.isRecord()) {
            for (PsiRecordComponent component : clazz.getRecordComponents()) {
                properties.putIfAbsent(component.getName(), schema(component.getType(), new HashSet<>(seen), depth + 1));
            }
        }
        Map<String, Object> result = new LinkedHashMap<>(); result.put("type", "object"); result.put("properties", properties);
        if (!required.isEmpty()) result.put("required", required);
        Map<String, Object> example = new LinkedHashMap<>();
        for (var field : properties.entrySet()) example.put(field.getKey(), example(field.getValue()));
        result.put("example", example);
        return result;
    }

    private static Object example(Object value) {
        if (!(value instanceof Map<?, ?> schema)) return "example";
        if (schema.containsKey("example")) return schema.get("example");
        if (schema.get("enum") instanceof List<?> values && !values.isEmpty()) return values.getFirst();
        if ("array".equals(schema.get("type"))) return List.of(example(schema.get("items")));
        if ("object".equals(schema.get("type"))) return Map.of();
        return "example";
    }

    private void applyValidation(PsiModifierList list, String key, Map<String, Object> schema, List<String> required) {
        for (PsiAnnotation annotation : list.getAnnotations()) {
            String qualified = annotation.getQualifiedName();
            if (qualified == null) continue;
            String name = qualified.substring(qualified.lastIndexOf('.') + 1);
            if ((qualified.startsWith("jakarta.validation.") || qualified.startsWith("javax.validation."))
                && Set.of("NotNull", "NotBlank", "NotEmpty").contains(name)) required.add(key);
            if ((qualified.startsWith("jakarta.validation.") || qualified.startsWith("javax.validation.")) && name.equals("Size")) {
                String minimum = SpringAnnotations.string(annotation, "min", "0");
                String maximum = SpringAnnotations.string(annotation, "max", "2147483647");
                String suffix = "array".equals(schema.get("type")) ? "Items" : "Length";
                schema.put("min" + suffix, Integer.parseInt(minimum));
                if (!maximum.equals("2147483647")) schema.put("max" + suffix, Integer.parseInt(maximum));
            }
            if ((qualified.startsWith("jakarta.validation.") || qualified.startsWith("javax.validation.")) && (name.equals("Min") || name.equals("Max"))) schema.put(name.equals("Min") ? "minimum" : "maximum",
                Long.parseLong(SpringAnnotations.string(annotation, "value", "0")));
            if (qualified.equals("io.swagger.v3.oas.annotations.media.Schema")) {
                String description = SpringAnnotations.string(annotation, "description", "");
                if (!description.isEmpty()) schema.put("description", description);
            }
        }
    }
}
