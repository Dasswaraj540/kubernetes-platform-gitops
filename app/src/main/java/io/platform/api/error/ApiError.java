package io.platform.api.error;

import java.time.Instant;
import java.util.List;

public record ApiError(
        Instant timestamp,
        int status,
        String error,
        String message,
        String path,
        List<String> details) {

    public ApiError {
        details = details == null ? List.of() : List.copyOf(details);
    }

    public List<String> details() {
        return List.copyOf(details);
    }
}
