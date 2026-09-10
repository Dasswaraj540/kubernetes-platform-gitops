package io.platform.api.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import io.platform.api.config.PlatformProperties;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class ItemServiceTest {

    private static ItemService service(int seedCount, int maxPageSize) {
        return new ItemService(new PlatformProperties(
                new PlatformProperties.Info("test", "local"),
                new PlatformProperties.Items(seedCount, maxPageSize)));
    }

    @Test
    void seedsRequestedNumberOfItems() {
        assertThat(service(7, 50).findAll()).hasSize(7);
        assertThat(service(7, 50).total()).isEqualTo(7);
    }

    @Test
    void findPageClampsToMaxPageSize() {
        assertThat(service(20, 5).findPage(10)).hasSize(5);
    }

    @Test
    void findPageClampsToAtLeastOne() {
        assertThat(service(20, 5).findPage(0)).hasSize(1);
    }

    @Test
    void seededItemsAreImmutable() {
        List<Item> items = service(3, 10).findAll();
        assertThatThrownBy(() -> items.add(new Item(99L, "x", "y", Instant.now())))
                .isInstanceOf(UnsupportedOperationException.class);
    }
}
