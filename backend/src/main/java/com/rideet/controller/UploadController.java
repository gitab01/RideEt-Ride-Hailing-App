package com.rideet.controller;

import com.rideet.dto.response.ApiResponse;
import com.rideet.service.FileStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

/**
 * Onboarding photos are taken on the driver's phone and have nowhere else to live, so the
 * API keeps them itself and hands back the URL the documents endpoint expects.
 */
@RestController
@RequestMapping("/uploads")
@RequiredArgsConstructor
public class UploadController {

    private final FileStorageService fileStorageService;

    @PostMapping("/document")
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadDocument(
            @RequestParam("file") MultipartFile file) {

        return ResponseEntity.ok(
                ApiResponse.success(Map.of("url", fileStorageService.store(file, "documents"))));
    }
}
