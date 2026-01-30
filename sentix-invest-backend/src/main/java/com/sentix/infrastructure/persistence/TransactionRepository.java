package com.sentix.infrastructure.persistence;

import com.sentix.domain.Transaction;
import com.sentix.domain.TransactionType;
import com.sentix.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, UUID> {

    List<Transaction> findByUserOrderByExecutedAtDesc(User user);

    List<Transaction> findByUserAndSymbolOrderByExecutedAtDesc(User user, String symbol);

    List<Transaction> findByUserAndTypeOrderByExecutedAtDesc(User user, TransactionType type);
}
