package com.rheq.idea;

import com.intellij.openapi.application.*;
import com.intellij.openapi.module.ModuleUtilCore;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.Messages;
import com.intellij.psi.*;
import com.intellij.util.concurrency.AppExecutorUtil;
import java.net.URI;

final class MethodImportFlow {
    static void openMethod(PsiMethod method) {
        if (!method.isValid()) return;
        var controller = method.getContainingClass();
        var module = ModuleUtilCore.findModuleForPsiElement(method);
        if (controller == null || module == null) return;
        open(method.getProject(), module, controller, method, ControllerScanner.Scope.METHOD);
    }

    static void open(Project project, com.intellij.openapi.module.Module module, PsiClass controller,
                     PsiMethod method, ControllerScanner.Scope scope) {
        String baseUrl = Messages.showInputDialog(project, BridgeMessages.text("base.prompt"), "RHEQ",
            Messages.getQuestionIcon(), "http://localhost:8080", null);
        if (baseUrl == null) return;
        try {
            URI uri = URI.create(baseUrl.trim());
            if (!("http".equals(uri.getScheme()) || "https".equals(uri.getScheme())) || uri.getHost() == null
                || uri.getUserInfo() != null || uri.getQuery() != null || uri.getFragment() != null) throw new IllegalArgumentException();
        } catch (IllegalArgumentException error) {
            Messages.showErrorDialog(project, BridgeMessages.text("base.invalid"), "RHEQ"); return;
        }
        String server = baseUrl.trim();
        ReadAction.nonBlocking(() -> ControllerScanner.scan(project, module, controller, method, scope, server))
            .inSmartMode(project).withDocumentsCommitted(project).expireWith(project)
            .finishOnUiThread(ModalityState.defaultModalityState(), result -> BridgeHandoff.preview(project, result))
            .submit(AppExecutorUtil.getAppExecutorService())
            .onError(error -> ApplicationManager.getApplication().invokeLater(() -> {
                if (!project.isDisposed()) Messages.showErrorDialog(project, error.toString(), "RHEQ");
            }));
    }
}
