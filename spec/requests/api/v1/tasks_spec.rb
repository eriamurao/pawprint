require 'rails_helper'

RSpec.describe 'Api::V1::Tasks', type: :request do
  describe 'GET /api/v1/tasks' do
    let!(:day_task) { create(:task, title: 'Day task', log_year: 2026, log_month: 7, log_day: 15) }
    let!(:other_day_task) { create(:task, title: 'Other day', log_year: 2026, log_month: 7, log_day: 16) }
    let!(:other_month_task) { create(:task, title: 'Other month', log_year: 2026, log_month: 8, log_day: 15) }
    let!(:archived_task) do
      create(:task, title: 'Archived', log_year: 2026, log_month: 7, log_day: 15, status: :archived)
    end

    it 'returns tasks scoped to the given day' do
      get '/api/v1/tasks', params: { filter: { type: 'daily', date: '2026-07-15' } }

      expect(response).to have_http_status(:ok)
      expect(json_response['tasks'].pluck('title')).to eq([ 'Day task' ])
    end

    it 'returns tasks scoped to the given month' do
      get '/api/v1/tasks', params: { filter: { type: 'monthly', date: '2026-07-01' } }

      expect(response).to have_http_status(:ok)
      expect(json_response['tasks'].pluck('title')).to contain_exactly('Day task', 'Other day')
    end

    it 'excludes archived tasks when no status filter is given' do
      get '/api/v1/tasks', params: { filter: { type: 'daily', date: '2026-07-15' } }

      expect(json_response['tasks'].pluck('title')).not_to include('Archived')
    end

    it 'returns an empty list for an invalid filter type' do
      get '/api/v1/tasks', params: { filter: { type: 'yearly', date: '2026-07-15' } }

      expect(response).to have_http_status(:ok)
      expect(json_response['tasks']).to eq([])
    end

    it 'returns an empty list when the date is missing' do
      get '/api/v1/tasks', params: { filter: { type: 'daily' } }

      expect(response).to have_http_status(:ok)
      expect(json_response['tasks']).to eq([])
    end

    it 'returns the task JSON shape' do
      get '/api/v1/tasks', params: { filter: { type: 'daily', date: '2026-07-15' } }

      task_json = json_response['tasks'].first
      expect(task_json.keys).to contain_exactly(
        'id', 'title', 'description', 'status', 'priority', 'log_date', 'available_events'
      )
      expect(task_json['log_date']).to eq('2026-07-15')
    end

    it 'returns 400 when the filter param is missing entirely' do
      get '/api/v1/tasks'

      expect(response).to have_http_status(:bad_request)
      expect(json_response['errors']).to eq([ 'filter is required' ])
    end
  end

  describe 'POST /api/v1/tasks' do
    it 'creates a task with valid params' do
      post '/api/v1/tasks', params: {
        task: { title: 'Buy milk', description: 'whole milk', date: '2026-07-20', priority: true }
      }

      expect(response).to have_http_status(:created)
      expect(json_response['task']['title']).to eq('Buy milk')
      expect(json_response['task']['description']).to eq('whole milk')
      expect(json_response['task']['priority']).to eq(true)
      expect(json_response['task']['log_date']).to eq('2026-07-20')
      expect(Task.count).to eq(1)
    end

    it 'returns 422 with invalid params' do
      post '/api/v1/tasks', params: { task: { title: '', date: '2026-07-20' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['errors']).to include("Title can't be blank")
      expect(Task.count).to eq(0)
    end

    it 'returns 400 when the task param is missing entirely' do
      post '/api/v1/tasks', params: {}

      expect(response).to have_http_status(:bad_request)
      expect(json_response['errors']).to eq([ 'task is required' ])
    end
  end

  describe 'PATCH /api/v1/tasks/:id' do
    let!(:task) { create(:task, title: 'Original title') }

    it 'updates the task with valid params' do
      patch "/api/v1/tasks/#{task.id}", params: { task: { title: 'Updated title' } }

      expect(response).to have_http_status(:ok)
      expect(json_response['task']['title']).to eq('Updated title')
      expect(task.reload.title).to eq('Updated title')
    end

    it 'returns 422 with invalid params' do
      patch "/api/v1/tasks/#{task.id}", params: { task: { title: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['errors']).to include("Title can't be blank")
    end

    it 'returns 404 for a non-existent task' do
      patch '/api/v1/tasks/0', params: { task: { title: 'Updated title' } }

      expect(response).to have_http_status(:not_found)
      expect(json_response['errors']).to eq([ 'Record not found' ])
    end
  end

  describe 'PATCH /api/v1/tasks/:id/transition' do
    let!(:task) { create(:task, status: :open) }

    it 'applies a permissible event' do
      patch "/api/v1/tasks/#{task.id}/transition", params: { event: 'start' }

      expect(response).to have_http_status(:ok)
      expect(json_response['task']['status']).to eq('in_progress')
      expect(task.reload.status).to eq('in_progress')
    end

    it 'returns 422 for a non-permissible event' do
      patch "/api/v1/tasks/#{task.id}/transition", params: { event: 'reopen' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['errors']).to eq([ 'Unable to apply the event' ])
      expect(task.reload.status).to eq('open')
    end

    it 'returns 422 for an unknown event' do
      patch "/api/v1/tasks/#{task.id}/transition", params: { event: 'bogus' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['errors']).to eq([ 'Unable to apply the event' ])
    end

    it 'returns 404 for a non-existent task' do
      patch '/api/v1/tasks/0/transition', params: { event: 'start' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/tasks/:id' do
    it 'deletes a deletable task' do
      task = create(:task, status: :open)

      delete "/api/v1/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response['message']).to eq('Task deleted successfully')
      expect(Task.exists?(task.id)).to eq(false)
    end

    it 'returns 422 for a non-deletable task and keeps it' do
      task = create(:task, status: :migrated)

      delete "/api/v1/tasks/#{task.id}"

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['errors']).to include("can't delete a task that has been deferred or migrated")
      expect(Task.exists?(task.id)).to eq(true)
    end

    it 'returns 404 for a non-existent task' do
      delete '/api/v1/tasks/0'

      expect(response).to have_http_status(:not_found)
    end
  end
end
