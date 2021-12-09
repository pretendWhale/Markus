describe AdminsController do
  let(:course) { admin.course }
  let(:admin) { create :admin }
  let(:role) { admin }
  let(:end_user) { create :end_user }

  context 'An Admin should' do
    context '#new' do
      it_behaves_like 'role is from a different course' do
        subject { get_as new_role, :new, params: { course_id: course.id } }
      end
      it 'be able to get :new' do
        get_as admin, :new, params: { course_id: course.id }
        expect(response.status).to eq(200)
      end
    end

    context '#index' do
      it_behaves_like 'role is from a different course' do
        subject { get_as new_role, :index, params: { course_id: course.id } }
      end
      it 'respond with success on index' do
        get_as admin, :index, params: { course_id: course.id }
        expect(response.status).to eq(200)
      end
    end

    context '#create' do
      it_behaves_like 'role is from a different course' do
        subject do
          post_as new_role, :create,
                  params: { course_id: course.id, role: { end_user: { user_name: end_user.user_name } } }
        end
      end
      it 'be able to create Admin' do
        post_as admin,
                :create,
                params: { course_id: course.id, role: { end_user: { user_name: end_user.user_name } } }
        expect(course.admins.joins(:end_user).where('users.user_name': end_user.user_name)).to exist
        expect(response).to redirect_to action: 'index'
      end
      context 'when a end_user does not exist' do
        let(:end_user) { build :end_user }
        subject do
          post_as admin, :create,
                  params: { course_id: course.id, role: { end_user: { user_name: end_user.user_name } } }
        end
        it 'should not create a Ta' do
          admin
          expect { subject }.not_to(change { Admin.count })
        end
      end
    end
    context '#update' do
      it_behaves_like 'role is from a different course' do
        subject do
          post_as new_role, :update,
                  params: { course_id: course.id, id: role, role: { end_user: { user_name: end_user.user_name } } }
        end
      end
      subject do
        post_as admin, :update,
                params: { course_id: course.id, id: role, role: { end_user: { user_name: new_end_user.user_name } } }
      end
      context 'when the new user exists' do
        let(:new_end_user) { create :end_user }
        it 'should change the user' do
          subject
          expect(role.reload.end_user).to eq(new_end_user)
        end
      end
      context 'when the user does not exist' do
        let(:new_end_user) { build :end_user }
        it 'should not change the user' do
          old_user = role.end_user
          subject
          expect(role.reload.end_user).to eq(old_user)
        end
      end
    end
  end
end
