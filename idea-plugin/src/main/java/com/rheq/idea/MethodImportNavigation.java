package com.rheq.idea;

import com.intellij.codeInsight.daemon.GutterIconNavigationHandler;
import com.intellij.psi.*;
import java.awt.event.MouseEvent;

final class MethodImportNavigation implements GutterIconNavigationHandler<PsiElement> {
    private final SmartPsiElementPointer<PsiMethod> pointer;
    MethodImportNavigation(PsiMethod method) { pointer = SmartPointerManager.createPointer(method); }
    PsiMethod selectedMethod() { return pointer.getElement(); }
    @Override public void navigate(MouseEvent event, PsiElement element) {
        PsiMethod method = selectedMethod();
        if (method != null) MethodImportFlow.openMethod(method);
    }
}
