package pagination

const (
	DefaultPage     = 1
	DefaultPageSize = 20
	MaxPageSize     = 100
)

type Params struct {
	Page     int `form:"page"`
	PageSize int `form:"page_size"`
}

func (p Params) Normalize() (page, pageSize, offset int) {
	page = p.Page
	if page < 1 {
		page = DefaultPage
	}
	pageSize = p.PageSize
	if pageSize < 1 {
		pageSize = DefaultPageSize
	}
	if pageSize > MaxPageSize {
		pageSize = MaxPageSize
	}
	offset = (page - 1) * pageSize
	return
}

type Result[T any] struct {
	Items      []T   `json:"items"`
	Total      int64 `json:"total"`
	Page       int   `json:"page"`
	PageSize   int   `json:"page_size"`
	TotalPages int   `json:"total_pages"`
}

func NewResult[T any](items []T, total int64, page, pageSize int) *Result[T] {
	if items == nil {
		items = []T{}
	}
	if pageSize <= 0 {
		pageSize = DefaultPageSize
	}
	totalPages := int((total + int64(pageSize) - 1) / int64(pageSize))
	return &Result[T]{
		Items:      items,
		Total:      total,
		Page:       page,
		PageSize:   pageSize,
		TotalPages: totalPages,
	}
}
