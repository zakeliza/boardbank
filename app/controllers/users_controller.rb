class UsersController < Devise::RegistrationsController
  # GET /users
  # GET /users.json

  def index
    @users = User.all
    @interests = Interest.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @users }
    end
  end

  # GET /users/1
  # GET /users/1.json
  def show
    
    @interests = Interest.all
    @skills = Skill.all

    #only show profile for the current user if user is logged in
    if current_user
      @user = current_user
    else
      @user = User.find(params[:id])
    end
    
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user }
    end
  end

  # GET /users/new
  # GET /users/new.json
  def new
    @user = User.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @user }
    end
  end

  # GET /users/1/edit
  def edit
    @interests = Interest.all
    @skills = Skill.all
    @user_skills = Hash[resource.user_skills.map { |user_skill| [user_skill.skill_id, user_skill] }]
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(params[:user])
    if @user.save
      sign_in(:user, @user)
      redirect_to "/", notice: 'You have successfully signed up as a prospective board member'

    else
      render action: 'new'
    end
  end

  # PUT /users/1
  # PUT /users/1.json
  def update

    user_params = params.require(:user).permit(:firstname, :lastname, :address,
 :city, :state, :zipcode, :phonenumber, :education, :areaofstudy, :email, :availability, :additional_comments, :password, :password_confirmation, :financial_contribution, :fundraise, :previous_experience, :current_password, :shownumber)

    if user_params[:state].empty?
      user_params.extract!(:state)
    end
    if user_params[:education].empty?
      user_params.extract!(:education)
    end
    
    require_password = true
    if user_params[:current_password].empty? and user_params[:password_confirmation].empty? and user_params[:password].empty?
      user_params.extract!(:current_password, :password_confirmation, :password)
      require_password = false
    end
    
    
    #debugger
    
    if (require_password and @user.update_with_password(user_params)) or ((not require_password) and @user.update_without_password(user_params))
      sign_in(@user, :bypass => true)
      #only update skills if password not required or supplied correctly 
      
      skill_params = params.require(:user)[:user_skills_attributes]
      if skill_params
        skill_params.each do |num, skill|
          if skill.has_key?("experience_level")
              skill_to_update = @user.user_skills.find_or_create_by(skill_id: skill[:skill_id])
              skill_to_update.update!(experience_level:skill[:experience_level])
          end
        end
      end
      
      if params[:interests].present?
        user_interests_params = params.require(:interests)
      else
         user_interests_params = []
      end
      interests_all = Interest.all
      if user_interests_params
        interests_all.each do |each_interest|
          interest_to_update = @user.user_interest.find_or_create_by(interest_id: each_interest[:id])
          interest_to_update.update!(has_interest: user_interests_params.member?(each_interest[:id].to_s))
        end
      end
        
      redirect_to user_path
      flash[:notice] = "Your account has been updated successfully."
    else
       @interests = Interest.all
       @skills = Skill.all
      @user_skills = Hash[resource.user_skills.map { |user_skill| [user_skill.skill_id, user_skill] }]
      render action: 'edit'
      
      #redirect_to edit_user_registration_path
      #flash[:alert] = @user.errors.full_messages.join(" and ").html_safe
    end

  end

  def index
    if params[:search].present?
      @users = User.search params[:search]
    elsif (params[:skill_ids].present? or params[:interest_ids].present?)
      if params[:skill_ids].present?
        ids = params.require(:skill_ids)
        @users = User.find_by_sql ["SELECT * FROM users
                 WHERE id IN
                 (SELECT user_id FROM
                   (SELECT COUNT(skill_id) AS count, user_id FROM
                    (SELECT user_id, skill_id FROM user_skills WHERE skill_id IN (?) AND (experience_level = 'Some' OR experience_level = 'Significant')) AS needsalias2
                    GROUP BY user_id) AS needsalias
                    WHERE count = ?)", ids, ids.length]
                 
                # ["SELECT * FROM users
                # WHERE id IN
                # (SELECT user_id FROM user_skills WHERE skill_id IN (?) AND (experience_level = 'Some' OR experience_level = 'Significant'))", ids]
      end
      if params[:interest_ids].present?
        if params[:skill_ids].present?
          users_temp = @users
        end
        ids = params.require(:interest_ids)
        @users = User.find_by_sql ["SELECT * FROM users
                 WHERE id IN
                 (SELECT user_id FROM
                   (SELECT COUNT(interest_id) AS count, user_id FROM
                    (SELECT user_id, interest_id FROM user_interests WHERE interest_id IN (?) AND (has_interest = 't')) AS needsalias2
                    GROUP BY user_id) AS needsalias
                    WHERE count = ?)", ids, ids.length]
        @users = @users.select {|user| users_temp.include? user} if not users_temp.nil?
      end
    else
       @users = User.all
    end
    @skills = Skill.all
    @interests = Interest.all
    @users = Kaminari.paginate_array(@users)
    if params[:page].present?
      @users = @users.page(params[:page])
    else
      @users = @users.page(1)
    end
    
    
  end

end