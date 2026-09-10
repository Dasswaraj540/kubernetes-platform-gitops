package io.platform.api.domain;

import java.time.Instant;

public record Item(long id, String name, String category, Instant createdAt) {
}
