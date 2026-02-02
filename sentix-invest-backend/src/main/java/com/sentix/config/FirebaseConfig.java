package com.sentix.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;
import java.io.InputStream;

@Configuration
@Slf4j
public class FirebaseConfig {

    @Value("${firebase.credentials.path:firebase-service-account.json}")
    private String firebaseCredentialsPath;

    @PostConstruct
    public void initialize() {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                InputStream serviceAccount;
                
                // Try to load from classpath
                try {
                    ClassPathResource resource = new ClassPathResource(firebaseCredentialsPath);
                    serviceAccount = resource.getInputStream();
                } catch (IOException e) {
                    log.warn("Firebase credentials not found at {}. Push notifications will be disabled.", 
                            firebaseCredentialsPath);
                    log.info("To enable push notifications, add firebase-service-account.json to resources/");
                    return;
                }

                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                FirebaseApp.initializeApp(options);
                log.info("✅ Firebase initialized successfully");
            }
        } catch (IOException e) {
            log.error("❌ Failed to initialize Firebase: {}", e.getMessage());
        }
    }
}
