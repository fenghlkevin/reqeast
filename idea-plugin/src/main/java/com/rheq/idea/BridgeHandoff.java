package com.rheq.idea;

import com.google.gson.GsonBuilder;
import com.intellij.openapi.application.PathManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.Messages;
import com.intellij.util.concurrency.AppExecutorUtil;
import com.intellij.openapi.application.ApplicationManager;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.UUID;

final class BridgeHandoff {
    static void preview(Project project, ControllerScanner.Export result) {
        if (result.count() == 0) { Messages.showErrorDialog(project, BridgeMessages.text("empty") + "\n" + String.join("\n", result.warnings().stream().limit(20).toList()), "RHEQ"); return; }
        String detail = BridgeMessages.text("preview", result.count()) + "\n\n" + String.join("\n", result.warnings().stream().limit(20).toList());
        if (Messages.showOkCancelDialog(project, detail, "RHEQ", BridgeMessages.text("send"),
            BridgeMessages.text("cancel"), Messages.getInformationIcon()) != Messages.OK) return;
        AppExecutorUtil.getAppExecutorService().execute(() -> {
            try {
                Path file = write(result);
                Path app = Path.of("/Applications/RHEQ.app");
                if (!Files.isDirectory(app)) throw new IOException(BridgeMessages.text("missing", file));
                Process process = new ProcessBuilder("/usr/bin/open", "-a", app.toString(), file.toString()).redirectErrorStream(true).start();
                String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
                if (process.waitFor() != 0) throw new IOException(output);
            } catch (Exception error) {
                if (error instanceof InterruptedException) Thread.currentThread().interrupt();
                ApplicationManager.getApplication().invokeLater(() -> {
                    if (!project.isDisposed()) Messages.showErrorDialog(project, error.toString(), "RHEQ");
                });
            }
        });
    }
    static Path write(ControllerScanner.Export result) throws IOException {
        byte[] bytes = new GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create().toJson(result.document()).getBytes(StandardCharsets.UTF_8);
        if (bytes.length > 5 * 1024 * 1024) throw new IOException("Export exceeds 5 MB");
        Path directory = Path.of(PathManager.getSystemPath(), "rheq-exports");
        Files.createDirectories(directory);
        Path file = directory.resolve(UUID.randomUUID() + ".rheqapi");
        Files.write(file, bytes, StandardOpenOption.CREATE_NEW);
        return file;
    }
}
