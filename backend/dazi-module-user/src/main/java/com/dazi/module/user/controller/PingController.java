package com.dazi.module.user.controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
@RequestMapping
public class PingController {
    @GetMapping("/ping")
    public Map<String, Object> ping(){
        return Map.of("module", "dazi-module-user", "status", "ok");
    }
}