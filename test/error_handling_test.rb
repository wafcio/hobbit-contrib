require 'helper'

scope Hobbit::ErrorHandling do
  NotFoundError = Class.new StandardError
  SpecificNotFoundError = Class.new NotFoundError
  UnknownError = Class.new ScriptError
  MustUseResponseError = Class.new StandardError

  setup do
    mock_app do
      include Hobbit::ErrorHandling

      error NotFoundError do
        'Not Found'
      end

      error MustUseResponseError do
        response.redirect '/'
      end

      error StandardError do
        exception = env['hobbit.error']
        exception.message
      end

      get '/' do
        'hello'
      end

      get '/raises' do
        raise RuntimeError, 'StandardError'
        'not this'
      end

      get '/other_raises' do
        raise NotFoundError
        response.write 'not this'
      end

      get '/same_other_raises' do
        raise SpecificNotFoundError
        response.write 'not this'
      end

      get '/must_use_response' do
        raise MustUseResponseError
        response.write 'not this'
      end
    end
  end

  scope '::error' do
    test do
      p = Proc.new { 'error' }
      app = mock_app do
        include Hobbit::ErrorHandling
        error StandardError, &p
      end

      assert_includes app.to_app.class.errors, StandardError
      assert_equal p.call, app.to_app.class.errors[StandardError].call
    end
  end

  scope '::errors' do
    test 'returns a Hash' do
      assert_kind_of Hash, app.to_app.class.errors
    end
  end

  scope 'when does not raise exception' do
    test 'works as expected' do
      get '/'
      assert last_response.ok?
      assert_equal 'hello', last_response.body
    end
  end

  scope 'when does raise an unknown exception class' do
    test 'does not halt default propagation of the unknown class' do
      mock_app do
        get '/uncaught_raise' do
          raise RuntimeError
        end
      end

      assert_raises RuntimeError do
        get '/uncaught_raise'
      end
    end
  end

  scope 'when raises a known exception class' do
    test 'calls the block set in error' do
      get '/raises'
      assert last_response.ok?
      assert_equal 'StandardError', last_response.body
    end

    test 'allows to define more than one exception' do
      get '/other_raises'
      assert last_response.ok?
      assert_equal 'Not Found', last_response.body
    end

    test 'allows to define a general exception class to catch' do
      get '/same_other_raises'
      assert last_response.ok?
      assert_equal 'Not Found', last_response.body
    end

    test 'sets the returned value of the error block as the body' do
      get '/other_raises'
      assert last_response.ok?
      assert_equal 'Not Found', last_response.body
      assert last_response.body != 'not this'
    end

    test 'overrides a previous block if a new one is passed' do
      app.to_app.class.error StandardError do
        'other handler!'
      end

      get '/raises'
      assert last_response.ok?
      assert_equal 'other handler!', last_response.body
    end

    test 'uses the response object' do
      get '/must_use_response'
      assert last_response.redirection?
      follow_redirect!
      assert_equal 'hello', last_response.body
    end
  end
end
