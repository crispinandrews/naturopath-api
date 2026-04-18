module Paginatable
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100

  private

  def paginate(scope)
    page = pagination_page
    per_page = pagination_per_page

    total_count = scope.count
    total_pages = (total_count.to_f / per_page).ceil

    paginated_scope = scope.offset((page - 1) * per_page).limit(per_page)

    [
      paginated_scope,
      {
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages
      }
    ]
  end

  def pagination_page
    parse_positive_integer(params[:page], fallback: DEFAULT_PAGE, field: :page)
  end

  def pagination_per_page
    per_page = parse_positive_integer(params[:per_page], fallback: DEFAULT_PER_PAGE, field: :per_page)
    return per_page if per_page <= MAX_PER_PAGE

    raise_invalid_pagination("per_page must be less than or equal to #{MAX_PER_PAGE}")
  end

  def parse_positive_integer(raw_value, fallback:, field:)
    return fallback if raw_value.blank?

    value = Integer(raw_value, 10)
    return value if value.positive?

    raise_invalid_pagination("#{field} must be greater than 0")
  rescue ArgumentError
    raise_invalid_pagination("#{field} must be an integer")
  end

  def raise_invalid_pagination(message)
    raise ApplicationController::InvalidPaginationError, message
  end
end
