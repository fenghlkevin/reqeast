package com.rheq.idea;

import com.intellij.psi.*;
import java.util.*;

final class ControllerOperation {
    private final DtoSchema schemas;
    ControllerOperation(List<String> warnings) { schemas = new DtoSchema(warnings); }

    Map<String, Object> operation(PsiMethod method, String controller, String operationId) {
        List<Map<String, Object>> parameters = new ArrayList<>();
        Map<String, Object> body = null;
        Map<String, Object> multipart = new LinkedHashMap<>();
        for (PsiParameter parameter : method.getParameterList().getParameters()) {
            PsiAnnotation requestBody = SpringAnnotations.direct(parameter, "RequestBody");
            PsiAnnotation part = SpringAnnotations.direct(parameter, "RequestPart");
            if (requestBody != null) {
                Map<String, Object> schema = schemas.schema(parameter.getType());
                body = Map.of("required", !SpringAnnotations.string(requestBody, "required", "true").equals("false"),
                    "content", Map.of("application/json", Map.of("schema", schema)));
                continue;
            }
            if (part != null) {
                multipart.put(bindingName(part, parameter), schemas.schema(parameter.getType())); continue;
            }
            String location = null; PsiAnnotation binding = null;
            for (String name : List.of("PathVariable", "RequestParam", "RequestHeader")) {
                binding = SpringAnnotations.direct(parameter, name);
                if (binding != null) { location = name.equals("PathVariable") ? "path" : name.equals("RequestHeader") ? "header" : "query"; break; }
            }
            if (location == null) {
                String type = parameter.getType().getCanonicalText();
                if (type.startsWith("jakarta.servlet.") || type.startsWith("javax.servlet.") || type.startsWith("org.springframework.")
                    || type.equals("java.security.Principal")) continue;
                // Unannotated scalar arguments follow Spring's request-parameter convention.
                Map<String, Object> schema = schemas.schema(parameter.getType());
                if ("object".equals(schema.get("type"))) {
                    Object properties = schema.get("properties");
                    if (properties instanceof Map<?, ?> map) for (var entry : map.entrySet())
                        parameters.add(Map.of("name", entry.getKey().toString(), "in", "query", "required", false, "schema", entry.getValue()));
                    continue;
                }
                parameters.add(Map.of("name", parameter.getName(), "in", "query", "required", false, "schema", schema)); continue;
            }
            Map<String, Object> schema = new LinkedHashMap<>(schemas.schema(parameter.getType()));
            String defaultValue = SpringAnnotations.string(binding, "defaultValue", "");
            boolean hasDefault = !defaultValue.isEmpty() && !defaultValue.contains("\ue000");
            // Do not copy literal credentials from source annotations.
            if (hasDefault && !bindingName(binding, parameter).toLowerCase(Locale.ROOT).matches(".*(token|password|secret|key).*"))
                schema.put("example", defaultExample(schema, defaultValue));
            parameters.add(Map.of("name", bindingName(binding, parameter), "in", location,
                "required", location.equals("path") || !hasDefault && !SpringAnnotations.string(binding, "required", "true").equals("false"), "schema", schema));
        }
        if (!multipart.isEmpty()) body = Map.of("content", Map.of("multipart/form-data", Map.of("schema", Map.of("type", "object", "properties", multipart))));
        Map<String, Object> operation = new LinkedHashMap<>();
        operation.put("operationId", operationId); operation.put("summary", SpringAnnotations.summary(method));
        operation.put("tags", List.of(controller)); operation.put("parameters", parameters);
        operation.put("responses", Map.of("200", Map.of("description", "Successful response")));
        if (body != null) operation.put("requestBody", body);
        return operation;
    }

    private static Object defaultExample(Map<String, Object> schema, String value) {
        try {
            if ("integer".equals(schema.get("type"))) return Long.parseLong(value);
            if ("number".equals(schema.get("type"))) return new java.math.BigDecimal(value);
            if ("boolean".equals(schema.get("type"))) return Boolean.parseBoolean(value);
        } catch (NumberFormatException ignored) { return schema.getOrDefault("example", "example"); }
        return value;
    }

    private static String bindingName(PsiAnnotation annotation, PsiParameter parameter) {
        return SpringAnnotations.string(annotation, "name", SpringAnnotations.string(annotation, "value", parameter.getName()));
    }
}
