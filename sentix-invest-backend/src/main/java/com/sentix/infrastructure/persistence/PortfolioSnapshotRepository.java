package com.sentix.infrastructure.persistence;

import com.sentix.domain.PortfolioSnapshot;
import com.sentix.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PortfolioSnapshotRepository extends JpaRepository<PortfolioSnapshot, UUID> {

    List<PortfolioSnapshot> findByUserAndIsPaperAndSnapshotDateBetweenOrderBySnapshotDateAsc(
            User user, Boolean isPaper, LocalDate startDate, LocalDate endDate);

    Optional<PortfolioSnapshot> findTopByUserAndIsPaperOrderBySnapshotDateDesc(User user, Boolean isPaper);

    boolean existsByUserAndSnapshotDateAndIsPaper(User user, LocalDate snapshotDate, Boolean isPaper);

    Optional<PortfolioSnapshot> findByUserAndSnapshotDateAndIsPaper(User user, LocalDate snapshotDate, Boolean isPaper);
}
