package io.platform.api.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import io.platform.api.config.PlatformProperties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(InfoController.class)
@EnableConfigurationProperties(PlatformProperties.class)
@TestPropertySource(properties = {
        "platform.info.environment=test",
        "platform.info.region=local-1"
})
class InfoControllerTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void returnsBuildAndEnvironmentMetadata() throws Exception {
        mvc.perform(get("/api/v1/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("platform-api"))
                .andExpect(jsonPath("$.version").value("0.1.0"))
                .andExpect(jsonPath("$.environment").value("test"))
                .andExpect(jsonPath("$.region").value("local-1"))
                .andExpect(jsonPath("$.javaVersion").exists());
    }
}
