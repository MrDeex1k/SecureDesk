//Schematy walidacji Zod dla danych wejściowych API

import { z } from "zod";
import type { Request, Response, NextFunction } from "express";

// =============================================================================
// Common Schemas
// =============================================================================

// UUIDv7 validation
export const uuidSchema = z.string().uuid({ message: "Nieprawidłowy format UUID" });

// Email validation
export const emailSchema = z
	.string()
	.email({ message: "Nieprawidłowy adres email" })
	.min(5, { message: "Email musi mieć co najmniej 5 znaków" })
	.max(255, { message: "Email może mieć maksymalnie 255 znaków" });

// Password validation (zgodne z Better-Auth config)
export const passwordSchema = z
	.string()
	.min(12, { message: "Hasło musi mieć co najmniej 12 znaków" })
	.max(128, { message: "Hasło może mieć maksymalnie 128 znaków" });

// Pagination schemas
export const paginationSchema = z.object({
	page: z.coerce.number().int().min(1).default(1),
	limit: z.coerce.number().int().min(1).max(100).default(20),
});

// =============================================================================
// Incident Schemas
// =============================================================================

// Zgodne z 03-create-app.sql: incident_status ENUM
export const incidentStatusSchema = z.enum([
	"pending",
	"analyzing",
	"resolved",
	"rejected",
]);

// Zgodne z 03-create-app.sql: incident_category ENUM
export const incidentCategorySchema = z.enum([
	"Czerwony",
	"Żółty",
	"Zielony",
]);

export const createIncidentSchema = z.object({
	userDescription: z
		.string()
		.min(10, { message: "Opis musi mieć co najmniej 10 znaków" })
		.max(5000, { message: "Opis może mieć maksymalnie 5000 znaków" }),
	userScreenshotData: z.record(z.string(), z.unknown()).optional(),
	userAttachmentData: z.record(z.string(), z.unknown()).optional(),
});

export const updateIncidentSchema = z.object({
	status: incidentStatusSchema.optional(),
	analystNote: z.string().max(10000, { message: "Notatka może mieć maksymalnie 10000 znaków" }).optional(),
	analystReportData: z.record(z.string(), z.unknown()).optional(),
	analystStatementData: z.record(z.string(), z.unknown()).optional(),
	llmCategory: incidentCategorySchema.optional(),
});

// =============================================================================
// Organization Schemas
// =============================================================================

export const userRoleSchema = z.enum(["admin", "analityk", "pracownik"]);

export const createOrganizationSchema = z.object({
	name: z
		.string()
		.min(2, { message: "Nazwa musi mieć co najmniej 2 znaki" })
		.max(100, { message: "Nazwa może mieć maksymalnie 100 znaków" }),
	slug: z
		.string()
		.min(2, { message: "Slug musi mieć co najmniej 2 znaki" })
		.max(50, { message: "Slug może mieć maksymalnie 50 znaków" })
		.regex(
			/^[a-z0-9-]+$/,
			{ message: "Slug może zawierać tylko małe litery, cyfry i myślniki" },
		),
	logo: z.string().url({ message: "Nieprawidłowy URL logo" }).optional(),
});

export const inviteMemberSchema = z.object({
	email: emailSchema,
	role: userRoleSchema.default("pracownik"),
});

// =============================================================================
// Query Schemas
// =============================================================================

export const incidentQuerySchema = paginationSchema.extend({
	status: incidentStatusSchema.optional(),
	userId: uuidSchema.optional(),
	sortBy: z.enum(["createdAt", "updatedAt", "status"]).default("createdAt"),
	sortOrder: z.enum(["asc", "desc"]).default("desc"),
});

// =============================================================================
// Validation Middleware Factory
// =============================================================================

type ValidateTarget = "body" | "query" | "params";

/**
 * Middleware factory do walidacji danych wejściowych
 *
 * @param schema - Schemat Zod do walidacji
 * @param target - Część requestu do walidacji (body, query, params)
 *
 * @example
 * router.post('/incidents', validate(createIncidentSchema, 'body'), handler)
 * router.get('/incidents', validate(incidentQuerySchema, 'query'), handler)
 */
export function validate<T extends z.ZodTypeAny>(
	schema: T,
	target: ValidateTarget = "body",
) {
	return (req: Request, res: Response, next: NextFunction): void => {
		try {
			const data = req[target];
			const result = schema.parse(data);

			// Zastąp oryginalne dane zwalidowanymi (z transformacjami i defaults)
			req[target] = result;

			next();
		} catch (error) {
			if (error instanceof z.ZodError) {
				const formattedErrors = error.issues.map((issue) => ({
					field: issue.path.join("."),
					message: issue.message,
				}));

				res.status(400).json({
					success: false,
					error: {
						code: "VALIDATION_ERROR",
						message: "Błąd walidacji danych",
						details: formattedErrors,
					},
				});
				return;
			}

			next(error);
		}
	};
}

/**
 * Walidacja wielu części requestu jednocześnie
 *
 * @example
 * router.put('/incidents/:id',
 *   validateMultiple({
 *     params: z.object({ id: uuidSchema }),
 *     body: updateIncidentSchema
 *   }),
 *   handler
 * )
 */
export function validateMultiple(schemas: {
	body?: z.ZodTypeAny;
	query?: z.ZodTypeAny;
	params?: z.ZodTypeAny;
}) {
	return (req: Request, res: Response, next: NextFunction): void => {
		const errors: { target: string; field: string; message: string }[] = [];

		for (const [target, schema] of Object.entries(schemas)) {
			if (!schema) continue;

			try {
				const data = req[target as ValidateTarget];
				const result = schema.parse(data);
				req[target as ValidateTarget] = result;
			} catch (error) {
				if (error instanceof z.ZodError) {
					errors.push(
						...error.issues.map((issue) => ({
							target,
							field: issue.path.join("."),
							message: issue.message,
						})),
					);
				}
			}
		}

		if (errors.length > 0) {
			res.status(400).json({
				success: false,
				error: {
					code: "VALIDATION_ERROR",
					message: "Błąd walidacji danych",
					details: errors,
				},
			});
			return;
		}

		next();
	};
}

// =============================================================================
// Type Inference Helpers
// =============================================================================

export type CreateIncidentInput = z.infer<typeof createIncidentSchema>;
export type UpdateIncidentInput = z.infer<typeof updateIncidentSchema>;
export type IncidentQueryInput = z.infer<typeof incidentQuerySchema>;
export type CreateOrganizationInput = z.infer<typeof createOrganizationSchema>;
export type InviteMemberInput = z.infer<typeof inviteMemberSchema>;
export type PaginationInput = z.infer<typeof paginationSchema>;
