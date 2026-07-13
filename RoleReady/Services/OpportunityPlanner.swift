import Foundation

struct OpportunityPlanner {
    func activeOpportunity(from opportunities: [Opportunity], now: Date = Date()) -> Opportunity? {
        let candidates = opportunities.filter {
            $0.status == .preparing || $0.status == .interviewing
        }
        let upcoming = candidates.compactMap { opportunity -> (Opportunity, Date)? in
            guard let date = opportunity.interviewDate ?? opportunity.closingDate,
                  date >= now else { return nil }
            return (opportunity, date)
        }
        if let nearest = upcoming.min(by: { lhs, rhs in
            if lhs.1 == rhs.1 { return lhs.0.updatedAt > rhs.0.updatedAt }
            return lhs.1 < rhs.1
        }) {
            return nearest.0
        }
        return candidates
            .filter { $0.interviewDate == nil && $0.closingDate == nil }
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    func latestUnreflectedInterview(
        from opportunities: [Opportunity],
        reflectedOpportunityIDs: Set<UUID>,
        now: Date = Date()
    ) -> Opportunity? {
        opportunities
            .filter {
                guard let interviewDate = $0.interviewDate else { return false }
                return interviewDate < now && !reflectedOpportunityIDs.contains($0.id)
            }
            .max { lhs, rhs in
                (lhs.interviewDate ?? .distantPast) < (rhs.interviewDate ?? .distantPast)
            }
    }
}
