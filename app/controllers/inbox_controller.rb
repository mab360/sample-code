class InboxController < ApplicationController
  layout "home"
  
  before_filter :load_profile

  def index
    @mailbox = (params[:mailbox].blank? ? "inbox" : params[:mailbox])
    @messages = current_user.send(@mailbox).page(params[:page]).per(10)
    if @mailbox == "inbox"
      @options = ["Read","Unread","Delete"]
    elsif @mailbox == "outbox"
      @options = ["Delete"]
    elsif @mailbox == "trash"
      @options = ["Read","Unread","Delete","Undelete"]
    end
  end

  def show
    unless params[:mailbox].blank?
      @message = current_user.send(params[:mailbox]).find(params[:id])
      message_from = @message.from.username
      message_created_at = @message.created_at.strftime('%A, %B %d, %Y at %I:%M %p')
      unless params[:mailbox] == "outbox"
        read_unread_messages(true,@message)
        @message_description = "On " + message_created_at +" <span class='recipient_name'>" + message_from + "</span> wrote :"
        @user_tokens = @message.from.username
      else
        @message_description = "You wrote to <span class='recipient_name'>" + message_from + "</span> at " + message_created_at + " :"
      end
    end
  end

  def new
    user = User.find_by_username(params[:rnd])
    @user_tokens = user.username if user.present?
  end

  def create
    unless params[:user_tokens].blank? or params[:subject].blank? or params[:body].blank?
      recipients = current_user.friends.all(:conditions => { :username =>  params[:user_tokens].split(",") })
      #User.all(:conditions => {:username => params[:user_tokens].split(",")})
      if recipients.present? and current_user.send_message?(params[:subject],params[:body],*recipients)
        redirect_to mailboxes_url, :notice => 'Successfully send message.'
      else
        flash[:alert] = "Unable to send message."
        render :action => "new"
      end
    else
      flash[:alert] = "Invalid input for sending message."
      render :action => "new"
    end
  end

  def update
    mapping = {}
    mapping[:user_object_name] = "current_user"
    mapping[:user_display_attribute] = "username"
    unless params[:messages].nil?
      messages = current_user.send(params[:mailbox]).find(params[:messages])
      if params[:option].downcase == "read"
        read_unread_messages(true,*messages)
      elsif params[:option].downcase == "unread"
        read_unread_messages(false,*messages)
      elsif params[:option].downcase == "delete"
        delete_messages(true,*messages)
      elsif params[:option].downcase == "undelete"
        delete_messages(false,*messages)
      end
      redirect_to box_mailboxes_url(params[:mailbox])
    else
      redirect_to box_mailboxes_url(params[:mailbox])
    end
  end

  def token
    query = "%" + params[:q] + "%"
    recipients = current_user.friends.all(:conditions => ['username like ?', query])
    respond_to do |format|
      format.json { render :json => recipients.map { |u| { "id" => u.username, "name" => u.username } } }
    end
  end

  def read_unread_messages(isRead, *messages)
    messages.each do |msg|
      if isRead
        msg.mark_as_read unless msg.read?
      else
        msg.mark_as_unread if msg.read?
      end
    end
  end

  def delete_messages(isDelete, *messages)
    messages.each do |msg|
      if isDelete
        msg.delete
      else
        msg.undelete
      end
    end
  end

  protected

  def load_profile
    @profile = current_user
    @followcheck = 0
    @user = current_user
    if !@profile.nil?
      if @user.follows?(@profile)
        @followcheck = 1
      else
        @followcheck = 0
      end

      @user_likes = current_user.likes

      followers = @profile.followers(User)
      followables = @profile.followables(User)

      @followers_count = followers.count
      @followable_count = followables.count

      @followers = followers
      @followables = followables

      @friendship_requests = current_user.friendships_awaiting_acceptance(:includes => [:friends, :user])

      @friends = current_user.friends

      if current_user && current_user.id == @profile.id
        @stories = Story.user_stories(current_user.id, params[:page], followables)
      else
        @stories = Story.user_stories(@profile.id, params[:page], followables)
      end
    end
  end

end