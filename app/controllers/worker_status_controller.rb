class WorkerStatusController < ApplicationController
  def show
    start = Time.now

    since_id = params[:since_id].presence || 0

    messages = current_user.messages.where('id > ?', since_id)

    result = messages.select('COUNT(id) AS count', 'MAX(id) AS max_id')
      .reorder(Arel.sql('min(created_at)')).first
    count, max_id = result.count, result.max_id

    # Max aggregate only works if there are any new messages.
    max_id = since_id if count == 0

    render json: {
      pending: Delayed::Job.pending.where('run_at <= ?', start).count,
      awaiting_retry: Delayed::Job.awaiting_retry.count,
      recent_failures: Delayed::Job.failed_jobs.where('failed_at > ?', 5.days.ago).count,
      message_count: count,
      max_id: max_id || 0,
      compute_time: Time.now - start
    }
  end
end
