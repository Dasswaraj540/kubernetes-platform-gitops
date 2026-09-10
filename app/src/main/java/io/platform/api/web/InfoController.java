package io.platform.api.web;

import io.platform.api.config.PlatformProperties;
import java.time.Instant;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.info.BuildProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/info")
public class InfoController {

    private final PlatformProperties properties;
    private final ObjectProvider<BuildProperties> buildProperties;

    public InfoController(PlatformProperties properties, ObjectProvider<BuildProperties> buildProperties) {
        this.properties = properties;
        this.buildProperties = buildProperties;
    }

    @GetMapping
    public InfoResponse info() {
        BuildProperties build = buildProperties.getIfAvailable();
        String version = build != null ? build.getVersion() : "0.1.0";
        Instant buildTime = build != null ? build.getTime() : null;
        return new InfoResponse(
                "platform-api",
                version,
                buildTime,
                properties.info().environment(),
                properties.info().region(),
                Runtime.version().toString());
    }

    public record InfoResponse(
            String name,
            String version,
            Instant buildTime,
            String environment,
            String region,
            String javaVersion) {
    }
}
