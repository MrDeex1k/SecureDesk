//Type Definitions

export type LoginMethod = "password" | "passkey" | "oauth";
export type UserRole = "admin" | "analityk" | "pracownik";
export type InvitationStatus = "pending" | "accepted" | "rejected" | "canceled";
export type IncidentStatus =
	| "pending"
	| "analyzing"
	| "resolved"
	| "rejected";

// Zgodne z 03-create-app.sql: incident_category ENUM
export type IncidentCategory = "Czerwony" | "Żółty" | "Zielony";

export interface ApiResponse<T = unknown> {
	success: boolean;
	data?: T;
	error?: {
		code: string;
		message: string;
	};
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
	pagination: {
		page: number;
		limit: number;
		total: number;
		totalPages: number;
	};
}

export interface User {
	id: string;
	name: string | null;
	email: string;
	emailVerified: boolean;
	image: string | null;
	isActive: boolean;
	passwordCompromised: boolean | null;
	passwordLastCheckedAt: Date | null;
	lastLoginMethod: LoginMethod | null;
	lastLoginAt: Date | null;
	createdAt: Date;
	updatedAt: Date;
}

export interface Organization {
	id: string;
	name: string;
	slug: string;
	logo: string | null;
	metadata: Record<string, unknown> | null;
	createdAt: Date;
	updatedAt: Date | null;
}

export interface Member {
	id: string;
	organizationId: string;
	userId: string;
	role: UserRole;
	createdAt: Date;
	updatedAt: Date | null;
}

export interface Team {
	id: string;
	organizationId: string;
	name: string;
	createdAt: Date;
	updatedAt: Date | null;
}

export interface Incident {
	id: string;
	userId: string;
	status: IncidentStatus;
	userDescription: string;
	userScreenshotData: Record<string, unknown>[] | null;
	userAttachmentData: Record<string, unknown>[] | null;
	analystNote: string | null;
	analystReportData: Record<string, unknown> | null;
	analystStatementData: Record<string, unknown> | null;
	llmCategory: IncidentCategory | null;
	createdAt: Date;
	updatedAt: Date;
}

export interface IncidentAuditLog {
	id: number;
	incidentId: string;
	changedBy: string | null;
	oldStatus: IncidentStatus | null;
	newStatus: IncidentStatus | null;
	changedAt: Date;
}

export interface ExtendedSession {
	id: string;
	userId: string;
	token: string;
	expiresAt: Date;
	ipAddress: string | null;
	userAgent: string | null;
	activeOrganizationId: string | null;
	activeTeamId: string | null;
	createdAt: Date;
	updatedAt: Date;
}

