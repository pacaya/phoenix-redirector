# phoenix redirector
a simple `redirect_back/2` helper function for Phoenix framework which redirects to previous url with option to send changeset.

## What it does:

Lets say we have a Post model and PostController controller. A typical `new`/`create` functions (similar things apply to `edit`/`update`) inside  controller would look like this:

```elixir
  def new(conn, _params) do
    changeset = Post.changeset(%Post{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"post" => post_params}) do
    changeset = Post.changeset(%Post{}, post_params)

    case Repo.insert(changeset) do
      {:ok, _post} ->
        conn
        |> put_flash(:info, "Post created successfully.")
        |> redirect(to: post_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
```

If everything is ok application redirects user to successful path, and if there are some validation errors it shows him a form with error messages. Wich means that first time a person fills out a form for a new post he or she uses `posts/new` route, but in case of validation errors route changes to `posts`. Which is inconsistent. Also our `create` function duplicates a call to a view from `new` function.

This module allows you to change this behavior. The code above would be transformed into something like this:

```elixir
  def new(conn, _params) do
    changeset = 
      Post.changeset(%Post{})
      |> replace_if_redirected(conn)

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"post" => post_params}) do
    changeset = Post.changeset(%Post{}, post_params)

    case Repo.insert(changeset) do
      {:ok, _post} ->
        conn
        |> put_flash(:info, "Post created successfully.")
        |> redirect(to: post_path(conn, :index))
      {:error, changeset} ->
        conn
        |> redirect_back(with: changeset)
    end
  end
```

Our `new` function knows how to render a form, and `create` function validates input and in case of errors redirects user back to `posts/new` route, saving changeset (with user input and validation messages) to session. You don't have to change anything in view to allow this to work properly.

## Setup

Place `phoenix_redirector.ex` inside your Phoenix project. 

Add `import PhoenixRedirector, only: [redirect_back: 1, redirect_back: 2, replace_if_redirected: 2]` to controller function in your web.ex file:

```elixir
  def controller do
    quote do
      use Phoenix.Controller

			...
      import PhoenixRedirector, only: [redirect_back: 1, redirect_back: 2, replace_if_redirected: 2]
    end
  end
```

Add `import PhoenixRedirector, only: [parse_previous_paths: 2]` to router function in your web.ex file:

```elixir
  def router do
    quote do
      use Phoenix.Router
      import PhoenixRedirector, only: [parse_previous_paths: 2]
    end
  end
```

Append `:parse_previous_paths` to the plug list on the browser pipeline in your router.ex file:

```elixir
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :parse_previous_paths
  end
```

## How to use

Use `replace_if_redirected(changeset, conn)` in your `new`/`edit` functions to dynamically decide which changeset to use. If we’ve got here from `redirect_back` with validation errors, this function returns changeset which was sent with redirection, otherwise it returns current changeset. 

Use `redirect_back(conn, opts \\ [])` in your `create`/`update` functions (instead of `render`) in case you have validation errors. 

### Options: 
* `:with` - changeset with user supplied fields and validation errors
* `:or_to` - ulr which is going to be used in (unlikely) event of not having url history in session 

You may see example usage in *What it does* section.