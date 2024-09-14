defmodule MyBlogWeb.BlogController do
  use MyBlogWeb, :controller

  alias MyBlog.Blog

  def index(conn, _params) do
    render(conn, :home, layout: false, posts: Blog.all_posts())
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, layout: false, post: Blog.get_post_by_id!(id))
  end
end
