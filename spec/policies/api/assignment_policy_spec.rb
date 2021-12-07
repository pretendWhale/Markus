describe Api::AssignmentPolicy do
  let(:user) { role.human }
  let(:context) { { role: role, real_user: user } }

  describe_rule :test_files? do
    succeed 'role is an admin' do
      let(:role) { build :admin }
    end
    succeed 'user is a test server' do
      let(:role) { nil }
      let(:user) { create :test_server }
    end
    failed 'role is a ta' do
      let(:role) { build :ta }
    end
    failed 'role is a student' do
      let(:role) { build :student }
    end
  end
end