package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Business error codes
const (
	CodeSuccess = 0

	// Common 1xxx
	CodeNotFound   = 1001
	CodeBadRequest = 1002

	// Notification 10xxx
	CodeInvalidStatus = 10001

	// Auth 11xxx
	CodeUnauthorized = 11001

	// System 90xxx
	CodeInternalError = 90001
)

type Response struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

func Success(c *gin.Context, data any) {
	c.JSON(http.StatusOK, Response{
		Code:    CodeSuccess,
		Message: "ok",
		Data:    data,
	})
}

func Created(c *gin.Context, data any) {
	c.JSON(http.StatusCreated, Response{
		Code:    CodeSuccess,
		Message: "created",
		Data:    data,
	})
}

func BadRequest(c *gin.Context, code int, message string) {
	c.AbortWithStatusJSON(http.StatusBadRequest, Response{
		Code:    code,
		Message: message,
	})
}

func NotFound(c *gin.Context, message string) {
	c.AbortWithStatusJSON(http.StatusNotFound, Response{
		Code:    CodeNotFound,
		Message: message,
	})
}

func InternalError(c *gin.Context, message string) {
	c.AbortWithStatusJSON(http.StatusInternalServerError, Response{
		Code:    CodeInternalError,
		Message: message,
	})
}

func Unauthorized(c *gin.Context, message string) {
	c.AbortWithStatusJSON(http.StatusUnauthorized, Response{
		Code:    CodeUnauthorized,
		Message: message,
	})
}

func NoContent(c *gin.Context) {
	c.Status(http.StatusNoContent)
}
