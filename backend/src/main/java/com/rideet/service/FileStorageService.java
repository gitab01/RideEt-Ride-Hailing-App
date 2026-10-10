package com.rideet.service;

import com.rideet.exception.BadRequestException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

/**
 * Local document store for onboarding photos.
 *
 * <p>Files land under {@code storage.dir} and are served back from {@code /files/**}. Names
 * are random UUIDs, so a document is only reachable by whoever was handed its URL.
 */
@Service
@Slf4j
public class FileStorageService {

    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp", "pdf");

    @Value("${storage.dir:./uploads}")
    private String storageDir;

    /**
     * @param category logical folder, e.g. {@code documents}
     * @return a path the client can render or send back to another endpoint
     */
    public String store(MultipartFile file, String category) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("No file was uploaded");
        }
        String extension = extensionOf(file.getOriginalFilename());
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new BadRequestException("Only jpg, png, webp or pdf files are accepted");
        }
        String safeCategory = category == null || category.isBlank() ? "misc" : sanitize(category);

        Path target = Paths.get(storageDir).toAbsolutePath().normalize()
                .resolve(safeCategory)
                .resolve(UUID.randomUUID() + "." + extension);
        try {
            Files.createDirectories(target.getParent());
            try (var in = file.getInputStream()) {
                Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            log.error("Could not store uploaded file", e);
            throw new BadRequestException("The upload could not be saved on this server");
        }
        return "/files/" + safeCategory + "/" + target.getFileName();
    }

    public Path root() {
        return Paths.get(storageDir).toAbsolutePath().normalize();
    }

    private String extensionOf(String filename) {
        if (filename == null) return "";
        int dot = filename.lastIndexOf('.');
        return dot < 0 ? "" : filename.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private String sanitize(String value) {
        if (!value.matches("[a-zA-Z0-9_-]{1,32}")) {
            throw new BadRequestException("Unsupported upload folder");
        }
        return value.toLowerCase(Locale.ROOT);
    }
}
