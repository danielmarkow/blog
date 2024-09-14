defmodule MyBlogWeb.BlogController do
  use MyBlogWeb, :controller

  alias MyBlog.Blog

  def index(conn, _params) do
    render(conn, :home, posts: Blog.all_posts())
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, post: Blog.get_post_by_id!(id))
  end

  def about(conn, _params) do
    render(conn, :about)
  end
end
