module Api
  module V1
    class TasksController < Api::BaseController
      before_action :set_task, only: [ :update, :transition, :destroy ]

      def index
        filters = TaskFilter.new(filter_params)
        tasks = filters.valid? ? Task.scoped_by(**filters.to_query) : Task.none

        render json: { tasks: tasks.as_json(task_json_options) }, status: :ok
      end

      def create
        task = Task.new(task_params)

        if task.save
          render json: { task: task.as_json(task_json_options) }, status: :created
        else
          render json: { errors: task.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        if @task.update(task_params)
          render json: { task: @task.as_json(task_json_options) }, status: :ok
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_content
        end
      end

      def transition
        if @task.apply_event(params[:event])
          render json: { task: @task.as_json(task_json_options) }, status: :ok
        else
          render json: { errors: [ 'Unable to apply the event' ] }, status: :unprocessable_content
        end
      end

      def destroy
        if @task.destroy
          render json: { message: 'Task deleted successfully' }, status: :ok
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def set_task
        @task = Task.find(params[:id])
      end

      def filter_params
        params.require(:filter).permit(:type, :date)
      end

      def task_params
        params.require(:task).permit(:title, :description, :date, :priority)
      end

      # TODO: Move to serializer if json options are used by other classes as well
      def task_json_options
        { only: [ :id, :title, :description, :status, :priority ], methods: [ :log_date, :available_events ] }
      end
    end
  end
end
