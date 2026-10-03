package com.rheq.idea;

import com.intellij.codeInsight.daemon.*;
import com.intellij.openapi.editor.markup.GutterIconRenderer;
import com.intellij.openapi.project.DumbService;
import com.intellij.openapi.util.IconLoader;
import com.intellij.psi.*;
import org.jetbrains.annotations.NotNull;
import javax.swing.Icon;
import java.util.Collection;
import java.util.List;

public final class ControllerImportLineMarkerProvider extends LineMarkerProviderDescriptor {
    private static final Icon ICON = IconLoader.getIcon("/icons/rheqImport.svg", ControllerImportLineMarkerProvider.class);
    @Override public String getName() { return BridgeMessages.text("gutter.name"); }
    @Override public Icon getIcon() { return ICON; }
    // Annotation resolution runs in the slow/background pass, never on the fast EDT pass.
    @Override public LineMarkerInfo<?> getLineMarkerInfo(@NotNull PsiElement element) { return null; }
    @Override public void collectSlowLineMarkers(@NotNull List<? extends PsiElement> elements,
                                                @NotNull Collection<? super LineMarkerInfo<?>> result) {
        for (PsiElement element : elements) {
            if (!(element instanceof PsiIdentifier) || !(element.getParent() instanceof PsiMethod method)
                || element != method.getNameIdentifier() || DumbService.isDumb(element.getProject())) continue;
            PsiClass controller = method.getContainingClass();
            if (controller == null || !SpringAnnotations.controller(controller) || SpringAnnotations.mapping(method) == null) continue;
            result.add(new LineMarkerInfo<>(element, element.getTextRange(), ICON,
                ignored -> BridgeMessages.text("gutter.import"), new MethodImportNavigation(method),
                GutterIconRenderer.Alignment.LEFT, () -> BridgeMessages.text("gutter.import")));
        }
    }
}
