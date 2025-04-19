# typed: false

# Comment.above_average needs to compare against the average, which is an expensive dependent
# subquery. CommentStat calculates and stores that once for a fast join.
class CommentStat < ApplicationRecord
  # has_many :comments # date(comments.created_at)

  validates :date, presence: true
  validates :average, presence: true

  # Fills daily records for the last 30 days, updating existing rows (in case the job runs don't
  # line up to date boundaries).
  def self.daily_fill!
    Comment.connection.execute <<~SQL
      insert into comment_stats (date, average)
      with avg_by_date as (
        select
          date(created_at - interval '5 hour') as date, avg(score) as average
        from comments
        where
          (comments.created_at - interval '5 hour') >= now() - interval '30 day' and
          comments.is_deleted = false
        group by date(created_at - interval '5 hour')
      )
      select date, average from avg_by_date
      on conflict (date) do update set average = excluded.average
    SQL
  end
end
