package com.rideet.config;

import com.rideet.service.FileStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Serves the uploaded onboarding documents straight off disk.
 *
 * <p>There is no object storage behind this product yet, so the API's own filesystem is the
 * store; the URLs are relative and the names are unguessable UUIDs.
 */
@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {

    private final FileStorageService fileStorageService;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String location = fileStorageService.root().toUri().toString();
        // Without the trailing separator Spring reads the location as a file, not a folder,
        // and every stored document comes back as "no such resource".
        if (!location.endsWith("/")) location = location + "/";
        registry.addResourceHandler("/files/**").addResourceLocations(location);
    }
}
