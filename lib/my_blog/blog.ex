defmodule MyBlog.Blog do
  alias MyBlog.Post

  defmodule NotFoundError do
    defexception [:message, plug_status: 404]
  end

  use NimblePublisher,
    build: Post,
    from: Application.app_dir(:my_blog, "priv/posts/**/*.md"),
    as: :posts,
    highlighters: []

  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  # export
  def all_posts, do: @posts

  def get_post_by_id!(id) do
    Enum.find(all_posts(), &(&1.id == id)) ||
      raise NotFoundError, "post with id=#{id} not found"
  end
end
