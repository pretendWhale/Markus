RSpec.describe 'Role Switching', type: :request do
  context 'when role switched', type: :request do
    let(:course1) { create :course }
    let(:course2) { create :course }
    let(:instructor) { create :instructor, course_id: course1.id }
    let(:instructor2) { create :instructor, course_id: course2.id }
    let(:student) { create :student, course_id: course1.id }
    before :each do
      ActionController::Base.allow_forgery_protection = true
      post '/', params: { user_login: instructor.user_name, user_password: 'x' }
      post "/courses/#{course1.id}/switch_role", params: { effective_user_login: student.user_name }
    end
    after :each do
      ActionController::Base.allow_forgery_protection = false
    end
    it 'redirects the login route to the course homepage' do
      get '/'
      expect(response).to redirect_to course_assignments_path(course1.id)
    end
    it 'redirects to the original course on attempt to access another course' do
      get '/courses', params: { id: course2.id }
      expect(response).to have_http_status(302)
    end
    it 'serves an error message' do
      get '/courses', params: { id: course2.id }
      follow_redirect!
      expect(flash[:error]).not_to be_empty
    end
  end
end
