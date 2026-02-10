package com.sentix.api.calendar;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/calendar")
@RequiredArgsConstructor
public class EconomicCalendarController {

    private final EconomicCalendarService calendarService;

    @GetMapping("/economic")
    public ResponseEntity<Map<String, Object>> getEconomicCalendar(
            @RequestParam(defaultValue = "7") int days) {
        Map<String, Object> calendar = calendarService.getEconomicCalendar(days);
        if (calendar == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(calendar);
    }
}
