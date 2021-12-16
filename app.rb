# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/reloader'
require './lib/user'
require './lib/space'
require './lib/booking'
require './lib/email'
require './database_connection_setup'
require 'sinatra/flash'

# AirBnB class
class AirBnb < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
  end

  enable :sessions, :method_override
  register Sinatra::Flash

  before do
    @user = User.find(session[:id])
  end

  get '/' do
    erb :index, :layout => false
  end

  get '/user/new' do
    erb :'users/signup'
  end

  post '/user/signup' do
    user = User.create(name: params[:name], email: params[:email], password: params[:password])
    if user.nil?
      flash[:error] = 'Email address in use. Please log in or sign up with a different email.'
      session[:id] = nil
    else
      session[:id] = user.id
      p user.email
      Email.send_email(user_email: user.email,event: :sign_up)
    end
    redirect 'user/signup/confirmation'
  end

  get '/user/signup/confirmation' do
    erb :'users/confirmation'
  end

  get '/user/login' do
    erb :'users/login'
  end

  post '/user/logout' do
    session.clear
    redirect '/'
  end

  post '/user/authenticate' do
    user = User.authenticate(params[:email], params[:password])
    if user.nil?
      flash[:error] = 'Incorrect email or password.'
      redirect '/user/login'
    else
      session[:id] = user.id
      redirect '/spaces'
    end
  end

  get '/user/bookings' do
    @made_requests = Booking.made_requests(session[:id])
    @received_requests = Booking.received_requests(session[:id])
    erb :'users/booking'
  end

  get '/spaces' do
    @spaces = Space.all
    erb :'spaces/index'
  end

  get '/spaces/new' do
    erb :'spaces/new'
  end

  post '/spaces' do
    space = Space.create(title: params[:title], description: params[:description], picture: params[:picture],
                           price: params[:price], user_id: session[:id], availability_from: params[:availability_from], availability_until: params[:availability_until])
    Email.send_email(user_email: @user.email, event: :create_listing)
    redirect "/spaces/#{space.id}"
  end

  get '/spaces/:id' do
    @space = Space.find(id: params[:id])
    @space_owner = User.find(@space.user_id)
    erb :'/spaces/space'
  end


  delete '/spaces/delete/:id' do
    Space.delete(id: params[:id])
    flash[:notice] = "Space deleted"
    redirect '/spaces'
  end

  get '/spaces/:id/update' do
    @space = Space.find(id: params[:id])
    @space_owner = User.find(@space.user_id)
    erb :'/spaces/update'
  end

  patch '/spaces/:id/update' do
    Space.update(id: params[:id], title: params[:title],
    description: params[:description], picture: params[:picture], price: params[:price],
    availability_from: params[:availability_from], availability_until: params[:availability_until])
    redirect "/spaces/#{params[:id]}"
  end

  get '/user/signup/confirmation' do
    erb :'users/confirmation'
  end

  get '/bookings/:id/new' do
    @space_id = params[:id]
    @available_dates = Space.list_available_dates(space: Space.find(id: @space_id))
    @unavailable_dates = Booking.unavailable_dates(params[:id])
    erb :'bookings/new'
  end

  post '/bookings/:id' do
    Booking.request(session[:id], params[:id], params[:date])
    redirect 'user/bookings'
  end

  post '/bookings/:id/confirm' do
    booking = Booking.confirm(params[:id], true)
    user = User.find(booking.user_id)
    Email.send_email(user_email: user.email, event: :booking_confirmed)
    redirect 'user/bookings'
  end

  post '/bookings/:id/reject' do
    booking = Booking.confirm(params[:id], false)
    user = User.find(booking.user_id)
    Email.send_email(user_email: user.email, event: :booking_rejected)
    redirect 'user/bookings'
  end


  run! if app_file == $PROGRAM_NAME
end
