package com.rideet.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * A document rejection has to carry the reason: the driver sees it on their documents screen and
 * has to know which paper to redo.
 */
@Data
public class DriverRejectionRequest {

    @NotBlank
    @Size(max = 300)
    private String reason;
}
