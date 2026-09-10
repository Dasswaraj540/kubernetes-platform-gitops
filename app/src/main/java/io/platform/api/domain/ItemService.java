package io.platform.api.domain;

import io.platform.api.config.PlatformProperties;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ItemService {

    private static final List<String> CATEGORIES =
            List.of("compute", "storage", "network", "observability", "security");

    private final List<Item> items;
    private final int maxPageSize;

    public ItemService(PlatformProperties properties) {
        this.maxPageSize = properties.items().maxPageSize();
        this.items = seed(properties.items().seedCount());
    }

    public List<Item> findAll() {
        return List.copyOf(items);
    }

    public List<Item> findPage(int requestedSize) {
        int size = Math.min(Math.max(requestedSize, 1), maxPageSize);
        return items.stream().limit(size).toList();
    }

    public int total() {
        return items.size();
    }

    public int maxPageSize() {
        return maxPageSize;
    }

    private static List<Item> seed(int count) {
        Instant base = Instant.now().minus(count, ChronoUnit.HOURS);
        List<Item> seeded = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            long id = i + 1L;
            String category = CATEGORIES.get(i % CATEGORIES.size());
            seeded.add(new Item(id, "item-" + id, category, base.plus(i, ChronoUnit.HOURS)));
        }
        return List.copyOf(seeded);
    }
}
