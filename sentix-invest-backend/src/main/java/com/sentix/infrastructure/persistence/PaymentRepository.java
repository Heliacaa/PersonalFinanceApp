package com.sentix.infrastructure.persistence;

import com.sentix.domain.Payment;
import com.sentix.domain.PaymentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, UUID> {

    Optional<Payment> findByConversationId(String conversationId);

    Optional<Payment> findByIyzicoToken(String token);

    List<Payment> findByUserIdOrderByCreatedAtDesc(UUID userId);

    List<Payment> findByUserIdAndStatus(UUID userId, PaymentStatus status);
}
