# frozen_string_literal: true

class DashboardsController < ApplicationController
  def show
    invoices = Current.user.account.invoices

    @outstanding_total = invoices.where(status: [ :draft, :sent ])
                                 .sum { |invoice| invoice.total }

    @overdue_invoices = invoices.where(status: [ :draft, :sent ])
                                .where("due_on < ?", Date.current)
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
