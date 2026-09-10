package io.platform.api.web;

import io.platform.api.domain.Item;
import io.platform.api.domain.ItemService;
import jakarta.validation.constraints.Min;
import java.util.List;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/items")
@Validated
public class ItemsController {

    private final ItemService itemService;

    public ItemsController(ItemService itemService) {
        this.itemService = itemService;
    }

    @GetMapping
    public ItemsResponse list(@RequestParam(name = "size", defaultValue = "0") @Min(0) int size) {
        List<Item> data = size == 0 ? itemService.findAll() : itemService.findPage(size);
        return new ItemsResponse(data.size(), itemService.total(), data);
    }

    public record ItemsResponse(int count, int total, List<Item> items) {
    }
}
