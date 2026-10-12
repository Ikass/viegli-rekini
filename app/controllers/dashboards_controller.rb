# frozen_string_literal: true

class DashboardsController < ApplicationController
  def show
    invoices = Current.user.account.invoices

    # Outstanding = issued but unpaid (sent). Drafts aren't owed yet, so they
    # don't count here or as overdue (mirrors Invoice#overdue?).
    @outstanding_total = invoices.sent
                                 .sum { |invoice| invoice.total }

    @overdue_invoices = invoices.overdue
    @overdue_count = @overdue_invoices.count
    @overdue_total = @overdue_invoices.sum(&:total)

    @paid_total = invoices.where(status: :paid)
                          .where(updated_at: Date.current.all_month)
                          .sum(&:total)

    @recent_invoices = invoices.order(updated_at: :desc)
                               .limit(5)
                               .includes(:client)
  end
end
