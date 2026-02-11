package com.sentix.infrastructure.persistence;

import com.sentix.domain.Transaction;
import com.sentix.domain.TransactionType;
import com.sentix.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, UUID> {

    List<Transaction> findByUserOrderByExecutedAtDesc(User user);

    Page<Transaction> findByUserOrderByExecutedAtDesc(User user, Pageable pageable);

    List<Transaction> findByUserAndSymbolOrderByExecutedAtDesc(User user, String symbol);

    List<Transaction> findByUserAndTypeOrderByExecutedAtDesc(User user, TransactionType type);

    List<Transaction> findByUserAndIsPaperOrderByExecutedAtDesc(User user, Boolean isPaper);

    Page<Transaction> findByUserAndIsPaperOrderByExecutedAtDesc(User user, Boolean isPaper, Pageable pageable);
}
