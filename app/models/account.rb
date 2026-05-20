# frozen_string_literal: true

class Account < ApplicationRecord
  has_many :users, dependent: :destroy

  validates :name, presence: true
end
