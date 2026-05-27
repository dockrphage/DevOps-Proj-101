package com.devops.demo;

import org.springframework.web.bind.annotation.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/scores")
public class ScoreController {
    
    private Map<String, Integer> scores = new ConcurrentHashMap<>();
    
    @GetMapping
    public Map<String, Integer> getAllScores() {
        return scores;
    }
    
    @PostMapping("/{player}")
    public String addScore(@PathVariable String player, @RequestParam int score) {
        scores.put(player, scores.getOrDefault(player, 0) + score);
        return String.format("Score added for %s. Total: %d", player, scores.get(player));
    }
    
    @GetMapping("/health")
    public String health() {
        return "OK";
    }
    
    @GetMapping("/info")
    public Map<String, String> info() {
        return Map.of(
            "version", "1.0.0",
            "environment", System.getProperty("spring.profiles.active", "default"),
            "hostname", System.getenv().getOrDefault("HOSTNAME", "unknown")
        );
    }
}
