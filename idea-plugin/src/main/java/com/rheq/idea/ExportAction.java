package com.rheq.idea;

import com.intellij.openapi.actionSystem.*;
import com.intellij.openapi.module.*;
import com.intellij.openapi.project.*;
import com.intellij.psi.*;
import com.intellij.psi.util.PsiTreeUtil;
import org.jetbrains.annotations.NotNull;

public abstract class ExportAction extends AnAction {
    private final ControllerScanner.Scope scope;
    protected ExportAction(ControllerScanner.Scope scope) { this.scope = scope; }
    @Override public @NotNull ActionUpdateThread getActionUpdateThread() { return ActionUpdateThread.BGT; }
    @Override public void update(@NotNull AnActionEvent event) {
        if (event.getProject() == null || DumbService.isDumb(event.getProject())) { event.getPresentation().setEnabledAndVisible(false); return; }
        Context context = context(event);
        event.getPresentation().setEnabledAndVisible(context != null && !DumbService.isDumb(context.project));
    }
    @Override public void actionPerformed(@NotNull AnActionEvent event) {
        Context context = context(event);
        if (context == null) return;
        MethodImportFlow.open(context.project, context.module, context.controller, context.method, scope);
    }
    private Context context(AnActionEvent event) {
        Project project = event.getProject();
        if (project == null) return null;
        PsiElement element = event.getData(CommonDataKeys.PSI_ELEMENT);
        var editor = event.getData(CommonDataKeys.EDITOR);
        PsiFile file = event.getData(CommonDataKeys.PSI_FILE);
        if (editor != null && file != null) element = file.findElementAt(editor.getCaretModel().getOffset());
        PsiMethod method = element == null ? null : PsiTreeUtil.getParentOfType(element, PsiMethod.class, false);
        PsiClass controller = element instanceof PsiClass clazz ? clazz : element == null ? null : PsiTreeUtil.getParentOfType(element, PsiClass.class, false);
        if (controller == null && file instanceof PsiJavaFile javaFile && javaFile.getClasses().length == 1) controller = javaFile.getClasses()[0];
        com.intellij.openapi.module.Module module = event.getData(LangDataKeys.MODULE);
        if (module == null && element != null) module = ModuleUtilCore.findModuleForPsiElement(element);
        if (module == null) return null;
        if (scope != ControllerScanner.Scope.MODULE && (controller == null || !SpringAnnotations.controller(controller))) return null;
        if (scope == ControllerScanner.Scope.METHOD && (method == null || SpringAnnotations.mapping(method) == null)) return null;
        return new Context(project, module, controller, method);
    }
    private record Context(Project project, com.intellij.openapi.module.Module module, PsiClass controller, PsiMethod method) {}
    public static final class Method extends ExportAction { public Method() { super(ControllerScanner.Scope.METHOD); } }
    public static final class Controller extends ExportAction { public Controller() { super(ControllerScanner.Scope.CONTROLLER); } }
    public static final class Module extends ExportAction { public Module() { super(ControllerScanner.Scope.MODULE); } }
}
