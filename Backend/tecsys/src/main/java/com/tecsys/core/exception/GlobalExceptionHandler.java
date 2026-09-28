package com.tecsys.core.exception;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(EmailAlreadyExistsException.class)
    public ResponseEntity<StandardError> handleEmailAlreadyExists(EmailAlreadyExistsException ex, HttpServletRequest request) {
        StandardError error = new StandardError(
                Instant.now(),
                HttpStatus.CONFLICT.value(),
                "Conflict",
                ex.getMessage(),
                request.getRequestURI(),
                null
        );
        return ResponseEntity.status(HttpStatus.CONFLICT).body(error);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<StandardError> handleValidationExceptions(MethodArgumentNotValidException ex, HttpServletRequest request) {
        List<StandardError.FieldError> fieldErrors = new ArrayList<>(ex.getBindingResult().getFieldErrors().stream()
                .map(f -> new StandardError.FieldError(f.getField(), f.getDefaultMessage()))
                .toList());

        ex.getBindingResult().getGlobalErrors().forEach(g ->
                fieldErrors.add(new StandardError.FieldError("Formulário", g.getDefaultMessage()))
        );

        StandardError error = new StandardError(
                Instant.now(),
                HttpStatus.BAD_REQUEST.value(),
                "Validation Error",
                "Erro na validação dos campos de entrada.",
                request.getRequestURI(),
                fieldErrors
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    @ExceptionHandler(BusinessRuleException.class)
    public ResponseEntity<StandardError> handleBusinessRuleException(BusinessRuleException ex, HttpServletRequest request) {
        StandardError error = new StandardError(
                Instant.now(),
                HttpStatus.UNPROCESSABLE_ENTITY.value(),
                "Unprocessable Entity",
                ex.getMessage(),
                request.getRequestURI(),
                null
        );
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(error);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<StandardError> handleAccessDeniedException(AccessDeniedException ex, HttpServletRequest request) {
        StandardError error = new StandardError(
                Instant.now(),
                HttpStatus.FORBIDDEN.value(),
                "Forbidden",
                ex.getMessage(),
                request.getRequestURI(),
                null
        );
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<StandardError> handleGenericException(Exception ex, HttpServletRequest request) {
        StandardError error = new StandardError(
                Instant.now(),
                HttpStatus.INTERNAL_SERVER_ERROR.value(),
                "Internal Server Error",
                "Ocorreu um erro interno no servidor.",
                request.getRequestURI(),
                null
        );

        ex.printStackTrace();

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
}