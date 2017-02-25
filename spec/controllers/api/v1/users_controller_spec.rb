require 'rails_helper'
#require 'helpers/base_helper_spec'

describe Api::V1::UsersController do
  describe "GET #index" do
    context "testing privileges" do
      it "non-user cannot see anything" do
        get :index
        expect_401_unauthorized
      end

      it "students cannot see anything" do
        create_and_authenticate_user(:user_student)
        get :index

        expect_401_unauthorized
      end

      it "managers are validated" do
        create_and_authenticate_user(:user_manager)
        get :index

        should respond_with 200
      end

      it "admins are validated" do
        create_and_authenticate_user(:user_admin)
        get :index

        should respond_with 200
      end
    end

    context "when enum values (status and privilege) are incorrect" do
      before(:each) do
        @user = create_and_authenticate_user(:user_admin)
        @user_attributes = FactoryGirl.attributes_for :user_admin
      end

      it "Status is incorrect" do
        @user_attributes[:status] = 'incorrect_status'
        get :index, @user_attributes

        user_response = expect_422_unprocessable_entity
        expect(user_response[:errors]).to include "Filter params are not correct as specified!"
      end

      it "Privilege is incorrect" do
        @user_attributes[:privilege] = 'incorrect_privilege'
        get :index, @user_attributes

        user_response = expect_422_unprocessable_entity
        expect(user_response[:errors]).to include "Filter params are not correct as specified!"
      end
    end
  end

  describe "GET #show" do
    before(:each) do
      @user = create_and_authenticate_user(:user_admin)
      get :show, id: @user.id
    end

    it "returns info about a reporter on a hash" do
      user_response = json_response
      expect(user_response[:email]).to eql @user.email
    end

    it { should respond_with 200 }
  end

  describe "POST #create" do
    context "when privileges are not enough" do
      before(:each) do
        @user_attributes = FactoryGirl.attributes_for :user_admin
      end

      it "non-user cannot create anything" do
        post :create, { user: @user_attributes }

        expect_401_unauthorized
      end

      it "student cannot create anything" do
        create_and_authenticate_user(:user_student)
        post :create, { user: @user_attributes }

        expect_401_unauthorized
      end

      it "manager cannot create anything" do
        create_and_authenticate_user(:user_manager)
        post :create, { user: @user_attributes }

        expect_401_unauthorized
      end
    end

    context "when enum values (status and privilege) are incorrect" do
      before(:each) do
        @user = create_and_authenticate_user(:user_admin)
        @user_attributes = FactoryGirl.attributes_for :user_admin
      end

      it "Status is incorrect" do
        @user_attributes[:status] = 'incorrect_status'
        post :create, { user: @user_attributes }

        user_response = expect_422_unprocessable_entity
        expect(user_response[:errors]).to include "Inputted params (Status or Privilege) are not as specified!"
      end

      it "Privilege is incorrect" do
        @user_attributes[:privilege] = 'incorrect_privilege'
        post :create, { user: @user_attributes }

        user_response = expect_422_unprocessable_entity
        expect(user_response[:errors]).to include "Inputted params (Status or Privilege) are not as specified!"
      end
    end

    # Successful user creation
    context "when is successfully created" do
      before(:each) do
        @user = create_and_authenticate_user(:user_admin)
        @user_attributes = FactoryGirl.attributes_for :user_admin

        post :create, { user: @user_attributes }
      end

      it "renders the json representation for the user record just created" do
        user_response = json_response
        expect(user_response[:email]).to eql @user_attributes[:email]
      end

      it { should respond_with 201 }
    end

    # Unsucessful creation
    context "when is not created" do
      before(:each) do
        @user = create_and_authenticate_user(:user_admin)
        @invalid_user_attributes = { password: "password",
                                     password_confirmation: "invalid_password" }
        post :create, { user: @invalid_user_attributes }
      end

      it "renders JSON error" do
        user_response = json_response
        expect(user_response).to have_key(:errors)
      end

      it "renders json errors on why user could not be created" do
        user_response = json_response
        expect(user_response[:errors][:password_confirmation]).to include "doesn't match Password"
      end

      it { should respond_with 422 }
    end
  end

  describe "PUT/PATCH #update" do
    context "when is successfully updated" do
      before(:each) do
        @user = create_and_authenticate_user(:user_admin)
        patch :update, { id: @user.id,
                        email: "newmailexample@duke.edu" }
      end

      it "renders json representation for updated user" do
        user_response = json_response
        expect(user_response[:email]).to eql "newmailexample@duke.edu"
      end

      it { should respond_with 200 }
    end

    context "when is not created as email is empty" do
      before(:each) do
        @user = create_and_authenticate_user(:user_admin)
        patch :update, { id: @user.id,
                        email: "" }
      end

      # TODO: Change when validation of email is finalized
      xit "renders error from JSON" do
        user_response = json_response
        expect(user_response).to have_key(:errors)
      end

      xit "renders the json errors on why the user couldn't be created" do
        user_response = json_response
        expect(user_response[:errors][:email]).to include "can't be blank"
      end

      xit { should respond_with 422 }
    end
  end

  describe "DELETE #destroy" do
    before(:each) do
      @user = create_and_authenticate_user(:user_admin)
      delete :destroy, { id: @user.id }
    end

    it { should respond_with 204 }
  end
end
