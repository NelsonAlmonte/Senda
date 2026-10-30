import type { Component } from 'svelte';

export type UiTone = 'neutral' | 'positive' | 'warning' | 'danger';

export type UiIcon = Component<{
	'aria-hidden'?: boolean | 'true' | 'false';
	size?: number;
	strokeWidth?: number;
}>;
