package com.sentix.api.common;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class PageResponseTest {

    @Test
    @DisplayName("from() correctly maps Spring Page to PageResponse")
    void from_mapsPageCorrectly() {
        List<String> content = List.of("item1", "item2", "item3");
        Page<String> page = new PageImpl<>(content, PageRequest.of(0, 10), 25);

        PageResponse<String> response = PageResponse.from(page, content);

        assertThat(response.content()).hasSize(3);
        assertThat(response.page()).isEqualTo(0);
        assertThat(response.size()).isEqualTo(10);
        assertThat(response.totalElements()).isEqualTo(25);
        assertThat(response.totalPages()).isEqualTo(3); // ceil(25/10) = 3
        assertThat(response.last()).isFalse();
    }

    @Test
    @DisplayName("from() correctly identifies last page")
    void from_identifiesLastPage() {
        List<String> content = List.of("item1", "item2");
        Page<String> page = new PageImpl<>(content, PageRequest.of(2, 10), 25);

        PageResponse<String> response = PageResponse.from(page, content);

        assertThat(response.page()).isEqualTo(2);
        assertThat(response.last()).isTrue();
    }

    @Test
    @DisplayName("from() handles empty page")
    void from_handlesEmptyPage() {
        List<String> content = List.of();
        Page<String> page = new PageImpl<>(content, PageRequest.of(0, 10), 0);

        PageResponse<String> response = PageResponse.from(page, content);

        assertThat(response.content()).isEmpty();
        assertThat(response.totalElements()).isEqualTo(0);
        assertThat(response.totalPages()).isEqualTo(0);
        assertThat(response.last()).isTrue();
    }

    @Test
    @DisplayName("from() supports mapped content different from source page type")
    void from_supportsMappedContent() {
        // Simulate mapping Entity -> DTO
        List<Integer> entityContent = List.of(1, 2, 3);
        Page<Integer> page = new PageImpl<>(entityContent, PageRequest.of(0, 10), 3);

        List<String> dtoContent = List.of("dto_1", "dto_2", "dto_3");
        PageResponse<String> response = PageResponse.from(page, dtoContent);

        assertThat(response.content()).containsExactly("dto_1", "dto_2", "dto_3");
        assertThat(response.totalElements()).isEqualTo(3);
    }

    @Test
    @DisplayName("from() handles single page with exact fit")
    void from_singlePageExactFit() {
        List<String> content = List.of("a", "b", "c", "d", "e");
        Page<String> page = new PageImpl<>(content, PageRequest.of(0, 5), 5);

        PageResponse<String> response = PageResponse.from(page, content);

        assertThat(response.totalPages()).isEqualTo(1);
        assertThat(response.last()).isTrue();
    }
}
