package io.platform.api.config;

import jakarta.validation.constraints.Positive;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "platform")
public record PlatformProperties(@DefaultValue Info info, @DefaultValue Items items) {

    public record Info(
            @DefaultValue("local") String environment,
            @DefaultValue("unknown") String region) {
    }

    public record Items(
            @DefaultValue("5") @Positive int seedCount,
            @DefaultValue("50") @Positive int maxPageSize) {
    }
}
