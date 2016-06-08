defmodule PhoenixRedirector do
	@moduledoc """
	this module implements redirect_back function, wich gives possibility to redirect
	to a previous url in case of an error and to send changeset with this redirect 

	you need to append :parse_previous_paths plug to a :browser pipeline in router.ex

	Also add 
	
	import PhoenixRedirector, only: [redirect_back: 1, redirect_back: 2, replace_if_redirected: 2]
		to controller section of web.ex
	
	and

	import PhoenixRedirector, only: [parse_previous_paths: 2]
 		to router section of web.ex
	"""

	import Plug.Conn, only: [get_session: 2, put_session: 3, assign: 3]
	import Phoenix.Controller, only: [redirect: 2]
	
	@doc """
	plug function, needs to be appended to :browser pipeline in router.ex
	"""
	def parse_previous_paths(conn, _opts) do
		previous_url = get_session(conn, :redirector_previous_visited_url)
		previous_changeset = get_session(conn, :redirector_saved_error_changset) |> extract_changeset
	
		conn
		|> save_if_get(:redirector_previous_visited_url, conn.request_path)
		|> put_session(:redirector_saved_error_changset, nil)
		|> assign(:redirector_previous_visited_url, previous_url)
		|> assign(:redirector_saved_error_changset, previous_changeset)
	end

	@doc """
	redirects to a previous location. Supports two keyword parameters:
	
	with: changeset - send changeset with redirect to have a possibility to handle errors
		(default value - nil)

	or_to: backup_url - url wich would be used if there is no previous url in session
		(default value - current url)
	"""
	def redirect_back(conn, opts \\ []) do
		opts = Map.merge(
			%{or_to: conn.request_path, with: nil}, 
			Enum.into(opts, %{})
		)

		conn
		|> put_changeset( opts[:with] )
		|> redirect( to: (conn.assigns[:redirector_previous_visited_url] || opts[:or_to]) )
	end

	@doc """
	if there is previous changeset wich was sent with redirect_back, returns it
	otherwise returns original changeset
	"""
	def replace_if_redirected(changeset, conn) do
		conn.assigns[:redirector_saved_error_changset] || changeset
	end

	#
	defp extract_changeset(changeset) when is_binary(changeset) do
		try do 
			:erlang.binary_to_term(changeset) 
		rescue 
			_ -> nil 
		end
	end
	#
	defp extract_changeset(_) do
		nil
	end

	#
	defp save_if_get(%{method: method} = conn, key, path) when method in ["GET", "HEAD"] do
		put_session(conn, key, path)
	end
	#
	defp save_if_get(conn, _, _) do
		conn
	end

	#
	defp put_changeset(conn, %{} = changeset) do
		put_session(conn, :redirector_saved_error_changset, :erlang.term_to_binary(changeset) )
	end
	#
	defp put_changeset(conn, _) do
		conn
	end
end