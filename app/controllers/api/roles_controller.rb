module Api
  class RolesController < MainApiController

    # Define default fields to display for index and show methods
    HUMAN_FIELDS = [:user_name, :email, :id_number, :first_name, :last_name].freeze
    ROLE_FIELDS = [:type, :grace_credits, :hidden].freeze
    DEFAULT_FIELDS = [:id, *HUMAN_FIELDS, *ROLE_FIELDS].freeze

    # Returns users and their attributes
    # Optional: filter, fields
    def index
      roles = get_collection || return
      respond_to do |format|
        format.xml { render xml: roles.to_xml(methods: DEFAULT_FIELDS,
                                              only: DEFAULT_FIELDS,
                                              root: :roles,
                                              skip_types: true) }
        format.json { render json: roles.to_json(only: DEFAULT_FIELDS, methods: DEFAULT_FIELDS) }
      end
    end

    # Creates a new role and user if it does not exist
    # Requires: user_name, type, first_name, last_name
    # Optional: section_name, grace_credits
    def create
      create_role
    end

    # Returns a user and its attributes
    # Requires: id
    # Optional: filter, fields
    def show
      role = Role.find_by_id(params[:id])
      if role.nil?
        # No user with that id
        render 'shared/http_status', locals: {code: '404', message:
            'No user exists with that id'}, status: 404
      else
        respond_to do |format|
          format.xml { render xml: role.to_xml(methods: DEFAULT_FIELDS,
                                               only: DEFAULT_FIELDS,
                                               root: :role,
                                               skip_types: true) }
          format.json { render json: role.to_json(only: DEFAULT_FIELDS, methods: DEFAULT_FIELDS) }
        end
      end
    end

    # Requires: id
    # Optional: first_name, last_name, user_name, section_name, grace_credits
    def update
      role = Role.find_by_id(params[:id])
      if role.nil?
        render 'shared/http_status', locals: {code: '404', message: 'User was not found'}, status: 404
      else
        update_role(role)
      end
    end

    # Update a user's attributes based on their user_name as opposed
    # to their id (use the regular update method instead)
    # Requires: user_name
    def update_by_username
      role = find_role_by_username
      update_role(role) unless role.nil?
    end

    # Creates a new user or unhides a user if they already exist
    # Requires: user_name, type, first_name, last_name
    # Optional: section_name, grace_credits
    def create_or_unhide
      role = find_role_by_username
      if role.nil?
        create_role
      else
        role.update!(hidden: false)
        render 'shared/http_status', locals: { code: '200', message:
            HttpStatusHelper::ERROR_CODE['message']['200'] }, status: 200
      end
    end

    private

    def create_role
      ApplicationRecord.transaction do
        human = Human.find_or_create_by!(human_params.permit(:user_name)) do |human|
          human.assign_attributes(human_params)
        end
        role = Role.new(**role_params, human: human, course: @current_course)
        role.section = Section.find_by(name: params[:section_name]) if params[:section_name]
        role.save!
        render 'shared/http_status', locals: { code: '201', message:
            HttpStatusHelper::ERROR_CODE['message']['201'] }, status: 201
      end
    rescue ActiveRecord::RecordInvalid => e
      render 'shared/http_status', locals: { code: '409', message: e.to_s }, status: 409
    rescue ActiveRecord::SubclassNotFound => e
      render 'shared/http_status', locals: { code: '422', message: e.to_s }, status: 422
    rescue StandardError
      render 'shared/http_status', locals: { code: '500', message:
          HttpStatusHelper::ERROR_CODE['message']['500'] }, status: 500
    end

    def update_role(role)
      ApplicationRecord.transaction do
        role.human.update!(params.permit(:first_name, :last_name, :user_name))
        role.section = Section.find_by(name: params[:section_name]) if params[:section_name]
        role.grace_credits = params[:grace_credits] if params[:grace_credits]
        role.save!
      end
      render 'shared/http_status', locals: { code: '200', message:
          HttpStatusHelper::ERROR_CODE['message']['200'] }, status: 200
    rescue ActiveRecord::RecordInvalid => e
      render 'shared/http_status', locals: { code: '409', message: e.to_s}, status: 409
    rescue ActiveRecord::SubclassNotFound => e
      render 'shared/http_status', locals: { code: '422', message: e.to_s }, status: 422
    rescue StandardError
      render 'shared/http_status', locals: { code: '500', message:
          HttpStatusHelper::ERROR_CODE['message']['500'] }, status: 500
    end

    def find_role_by_username
      if has_missing_params?([:user_name])
        # incomplete/invalid HTTP params
        render 'shared/http_status', locals: { code: '422', message:
            HttpStatusHelper::ERROR_CODE['message']['422'] }, status: 422
        return
      end

      # Check if that user_name is taken
      human = Human.find_by_user_name(params[:user_name])
      role = Role.find_by(human: human, course: @current_course)
      if role.nil?
        render 'shared/http_status', locals: { code: '404', message: 'Role was not found' }, status: 404
        return
      end
      role
    end

    def get_collection
      collection = Role.includes(:human).where(params.permit(:course_id)).order(:id)
      if params[:filter]&.present?
        role_filter = params[:filter].permit(*ROLE_FIELDS).to_h
        human_filter = params[:filter].permit(*HUMAN_FIELDS).to_h.map { |k, v| ["users.#{k}", v] }.to_h
        filter_params = {**role_filter, **human_filter}
        if filter_params.empty?
          render 'shared/http_status',
                 locals: { code: '422', message: 'Invalid or malformed parameter values' }, status: 422
          return false
        else
          return collection.where(filter_params)
        end
      end
      collection
    end

    def human_params
      params.permit(:user_name, :first_name, :last_name)
    end

    def role_params
      params.permit(:type, :grace_credits)
    end
  end
end
