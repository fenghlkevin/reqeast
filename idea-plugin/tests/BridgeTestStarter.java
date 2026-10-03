package com.rheq.idea;

import com.intellij.openapi.application.*;
import com.intellij.ide.impl.OpenProjectTask;
import com.intellij.openapi.roots.ModuleRootManager;
import com.intellij.openapi.projectRoots.JavaSdk;
import com.intellij.openapi.projectRoots.ProjectJdkTable;
import com.intellij.openapi.module.ModuleManager;
import com.intellij.openapi.project.*;
import com.intellij.openapi.project.ex.ProjectManagerEx;
import com.intellij.psi.*;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.google.gson.GsonBuilder;
import java.nio.file.*;
import java.util.*;

public final class BridgeTestStarter implements ApplicationStarter {
    @Override public int getRequiredModality() { return ApplicationStarter.NOT_IN_EDT; }
    @Override public boolean isHeadless() { return true; }
    @Override public void main(List<String> args) {
        try {
            for (String id : List.of("Rheq.ExportMethod", "Rheq.ExportController", "Rheq.ExportModule")) {
                if (com.intellij.openapi.actionSystem.ActionManager.getInstance().getAction(id) == null)
                    throw new AssertionError("Action not registered: " + id);
            }
            Path fixture = Path.of(args.get(1));
            Project project = ProjectManagerEx.getInstanceEx().openProject(Path.of(args.get(3)), OpenProjectTask.Companion.build());
            if (project == null) throw new AssertionError("Project unavailable");
            com.intellij.openapi.module.Module[] module = ModuleManager.getInstance(project).getModules();
            if (module.length != 1) throw new AssertionError("Fixture module unavailable");
            var virtual = LocalFileSystem.getInstance().refreshAndFindFileByNioFile(fixture);
            if (virtual == null) throw new AssertionError("Fixture VFS unavailable");
            var sdk = JavaSdk.getInstance().createJdk("Fixture JDK", System.getProperty("java.home"), false);
            ApplicationManager.getApplication().invokeAndWait(() -> WriteAction.run(() -> {
                ProjectJdkTable.getInstance().addJdk(sdk);
                var model = ModuleRootManager.getInstance(module[0]).getModifiableModel();
                model.setSdk(sdk); model.commit();
            }));
            DumbService.getInstance(project).waitForSmartMode();
            ControllerScanner.Export result = ReadAction.compute(() -> {
                PsiJavaFile file = (PsiJavaFile) PsiManager.getInstance(project).findFile(virtual);
                PsiClass controller = Arrays.stream(file.getClasses()).filter(c -> c.getName().equals("DemoController")).findFirst().orElseThrow();
                if (JavaPsiFacade.getInstance(project).findClass("java.lang.String", com.intellij.psi.search.GlobalSearchScope.allScope(project)) == null)
                    throw new AssertionError("JDK String PSI unavailable");
                if (com.intellij.codeInsight.daemon.LineMarkerProviders.getInstance().allForLanguage(com.intellij.lang.java.JavaLanguage.INSTANCE)
                    .stream().noneMatch(provider -> provider instanceof ControllerImportLineMarkerProvider))
                    throw new AssertionError("Gutter provider not registered");
                List<com.intellij.codeInsight.daemon.LineMarkerInfo<?>> markers = new ArrayList<>();
                var identifiers = new ArrayList<PsiElement>(com.intellij.psi.util.PsiTreeUtil.collectElementsOfType(file, PsiIdentifier.class));
                new ControllerImportLineMarkerProvider().collectSlowLineMarkers(identifiers, markers);
                if (markers.size() != 3) throw new AssertionError("Expected exactly one gutter marker per mapped method: " + markers.size());
                for (var marker : markers) {
                    var target = ((MethodImportNavigation) marker.getNavigationHandler()).selectedMethod();
                    if (target == null || marker.getElement() != target.getNameIdentifier()) throw new AssertionError("Marker target mismatch");
                    if (marker.getIcon() == null) throw new AssertionError("Gutter icon unavailable");
                    if (target.getName().equals("get")) {
                        var clicked = ControllerScanner.scan(project, module[0], controller, target, ControllerScanner.Scope.METHOD, "http://localhost:8080/api");
                        if (clicked.count() != 1 || !clicked.document().get("paths").toString().contains("/orders/{id}"))
                            throw new AssertionError("Gutter export must contain only the clicked endpoint");
                    }
                }
                ControllerScanner.Export export = ControllerScanner.scan(project, module[0], controller, null, ControllerScanner.Scope.CONTROLLER, "http://localhost:8080/api");
                if (export.count() != 2) throw new AssertionError("Expected 2 operations: " + export);
                var method = Arrays.stream(controller.getMethods()).filter(m -> m.getName().equals("get")).findFirst().orElseThrow();
                var single = ControllerScanner.scan(project, module[0], controller, method, ControllerScanner.Scope.METHOD, "http://localhost:8080/api");
                if (single.count() != 1) throw new AssertionError("Method scope failed");
                var all = ControllerScanner.scan(project, module[0], null, null, ControllerScanner.Scope.MODULE, "http://localhost:8080/api");
                if (all.count() != 2) throw new AssertionError("Module scope failed: " + all);
                if (export.warnings().stream().noneMatch(w -> w.contains("manual configuration"))) throw new AssertionError("Dynamic path warning missing");
                return export;
            });
            Files.writeString(Path.of(args.get(2)), new GsonBuilder().setPrettyPrinting().create().toJson(result.document()));
            System.out.println("RHEQ_PSI_TEST_OK interfaces=" + result.count());
            System.exit(0);
        } catch (Throwable error) {
            error.printStackTrace(); System.exit(1);
        }
    }
}
