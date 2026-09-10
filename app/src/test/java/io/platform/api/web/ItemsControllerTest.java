package io.platform.api.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import io.platform.api.config.PlatformProperties;
import io.platform.api.domain.ItemService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ItemsController.class)
@Import(ItemService.class)
@EnableConfigurationProperties(PlatformProperties.class)
@TestPropertySource(properties = {
        "platform.items.seed-count=4",
        "platform.items.max-page-size=10"
})
class ItemsControllerTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void listsAllItemsByDefault() throws Exception {
        mvc.perform(get("/api/v1/items"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(4))
                .andExpect(jsonPath("$.total").value(4))
                .andExpect(jsonPath("$.items.length()").value(4));
    }

    @Test
    void limitsToRequestedSize() throws Exception {
        mvc.perform(get("/api/v1/items").param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(2))
                .andExpect(jsonPath("$.total").value(4));
    }

    @Test
    void rejectsNegativeSize() throws Exception {
        mvc.perform(get("/api/v1/items").param("size", "-1"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void rejectsNonNumericSize() throws Exception {
        mvc.perform(get("/api/v1/items").param("size", "abc"))
                .andExpect(status().isBadRequest());
    }
}
